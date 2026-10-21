/**
 * Concurrent food claim against Postgres.
 * Skips when DATABASE_URL is unset (default unit suite uses memory repos).
 */
import { randomUUID } from 'node:crypto';
import { uniqueTestPhone } from './test-phone.js';
import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { createValidationPipe } from '../../src/platform/http/create-validation-pipe.js';
import { HttpExceptionFilter } from '../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../src/platform/http/response.interceptor.js';
import { loadEnv } from '../../src/platform/config/env.js';
import { IDENTITY_REPOSITORY, SMS_SENDER } from '../../src/modules/identity/identity.constants.js';
import { UniqueConflictError } from '../../src/modules/identity/identity.repository.js';
import { MockSmsSender } from '../../src/integrations/sms/sms-sender.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { FoodModule } from '../../src/modules/food-order/food.module.js';
import { CatalogModule } from '../../src/modules/catalog/catalog.module.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

const dropoff = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };

describePg('food claim race (postgres)', () => {
  let app: INestApplication;
  let sms: MockSmsSender;
  let prisma: PrismaService;

  beforeAll(async () => {
    sms = new MockSmsSender('test');
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              DATABASE_URL: process.env.DATABASE_URL,
              JWT_ACCESS_SECRET: 'test-access-secret',
              SMS_PROVIDER: 'mock',
              PUSH_PROVIDER: 'mock',
              PARTNER_ELIGIBILITY_BYPASS: 'true',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
              FOOD_MIN_DELIVERY_VND: '5000',
              FOOD_MAX_DELIVERY_VND: '100000',
              MAX_CONCURRENT_JOBS_PER_DRIVER: '2',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PrismaModule,
        FoodModule,
        CatalogModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    prisma = app.get(PrismaService);
    if (!prisma.db()) {
      throw new Error('DATABASE_URL did not open a Prisma client');
    }
  });

  afterAll(async () => {
    await app.close();
  });

  async function login(): Promise<{ token: string; userId: string }> {
    const phone = uniqueTestPhone();
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    return {
      token: verified.body.data.accessToken as string,
      userId: verified.body.data.user.id as string,
    };
  }

  it('lets only one of two racing claims win against Postgres', async () => {
    const customer = await login();
    const merchant = await login();
    const driverA = await login();
    const driverB = await login();
    const identity = app.get(IDENTITY_REPOSITORY);
    await ensureGrant(identity, merchant.userId, 'MERCHANT');
    await ensureGrant(identity, driverA.userId, 'DRIVER');
    await ensureGrant(identity, driverB.userId, 'DRIVER');

    const suffix = `${Date.now()}-${randomUUID().slice(0, 8)}`;
    await request(app.getHttpServer())
      .get('/v1/food/merchant/catalog')
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    const createdItem = await request(app.getHttpServer())
      .post('/v1/food/merchant/items')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ name: `Race Bun ${suffix}`, priceVnd: 45_000 })
      .expect(200);
    const catalog = await request(app.getHttpServer())
      .get('/v1/food/merchant/catalog')
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    const storeId = catalog.body.data.id as string;
    const itemId = createdItem.body.data.id as string;

    const placed = await request(app.getHttpServer())
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `pg-food-claim-${suffix}`)
      .send({
        storeId,
        dropoff,
        deliveryFareVnd: 15_000,
        items: [{ itemId, quantity: 1 }],
      });
    if (placed.status !== 200) {
      throw new Error(
        `place failed ${placed.status}: ${JSON.stringify(placed.body)}`,
      );
    }
    const orderId = placed.body.data.id as string;

    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/accept`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/ready`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);

    const [first, second] = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/food/orders/${orderId}/claim`)
        .set('Authorization', `Bearer ${driverA.token}`),
      request(app.getHttpServer())
        .post(`/v1/food/orders/${orderId}/claim`)
        .set('Authorization', `Bearer ${driverB.token}`),
    ]);

    const statuses = [first.status, second.status].sort((a, b) => a - b);
    expect(statuses).toEqual([200, 409]);
    const success = first.status === 200 ? first : second;
    const rejected = first.status === 409 ? first : second;
    expect(success.body.data.status).toBe('ASSIGNED');
    expect(rejected.body.errorCode).toBe('FOOD_ALREADY_ASSIGNED');
  });
});

async function ensureGrant(
  identity: {
    insertGrant: (
      userId: string,
      role: 'DRIVER' | 'MERCHANT',
      status: 'ACTIVE',
    ) => Promise<unknown>;
  },
  userId: string,
  role: 'DRIVER' | 'MERCHANT',
): Promise<void> {
  try {
    await identity.insertGrant(userId, role, 'ACTIVE');
  } catch (error) {
    if (!(error instanceof UniqueConflictError)) {
      throw error;
    }
  }
}
