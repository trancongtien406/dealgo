import { seedDriverClass } from './driver-class.js';
/**
 * Delivery-fee negotiation (counter / select / claim / raise) against Postgres.
 * Skips when DATABASE_URL is unset (default unit suite uses memory repos).
 */
import { randomUUID } from 'node:crypto';
import { uniqueTestPhone } from './test-phone.js';
import { pinStore } from './store-pin.js';
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

describePg('food delivery-fee negotiation race (postgres)', () => {
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

  async function readyOrder(suffix: string) {
    const customer = await login();
    const merchant = await login();
    const driverA = await login();
    const driverB = await login();
    const identity = app.get(IDENTITY_REPOSITORY);
    await ensureGrant(identity, merchant.userId, 'MERCHANT');
    for (const d of [driverA, driverB]) {
      await ensureGrant(identity, d.userId, 'DRIVER');
      await seedDriverClass(app, d.userId);
    }
    const http = request(app.getHttpServer());
    await request(app.getHttpServer()).get('/v1/food/merchant/catalog').set('Authorization', `Bearer ${merchant.token}`).expect(200);
    const item = await request(app.getHttpServer())
      .post('/v1/food/merchant/items')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ name: `Fee Bun ${suffix}`, priceVnd: 45_000 })
      .expect(200);
    const catalog = await request(app.getHttpServer()).get('/v1/food/merchant/catalog').set('Authorization', `Bearer ${merchant.token}`).expect(200);
    await pinStore(app, merchant.token);
    void http;
    const placed = await request(app.getHttpServer())
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `pg-food-fee-${suffix}`)
      .send({ storeId: catalog.body.data.id, dropoff, items: [{ itemId: item.body.data.id, quantity: 1 }] });
    if (placed.status !== 200) throw new Error(`place failed ${placed.status}: ${JSON.stringify(placed.body)}`);
    const orderId = placed.body.data.id as string;
    await request(app.getHttpServer()).post(`/v1/food/orders/${orderId}/accept`).set('Authorization', `Bearer ${merchant.token}`).expect(200);
    await request(app.getHttpServer()).post(`/v1/food/orders/${orderId}/ready`).set('Authorization', `Bearer ${merchant.token}`).expect(200);
    return { customer, driverA, driverB, orderId, fare: placed.body.data.deliveryFareVnd as number };
  }

  it('customer select of a counter vs another driver claiming: exactly one wins', async () => {
    const suffix = `${Date.now()}-${randomUUID().slice(0, 8)}`;
    const { customer, driverA, driverB, orderId, fare } = await readyOrder(suffix);
    const counter = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/delivery-offers`)
      .set('Authorization', `Bearer ${driverA.token}`)
      .send({ amountVnd: Math.ceil((fare + 1000) / 1000) * 1000 });
    expect(counter.status).toBe(200);
    const [select, claim] = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/food/orders/${orderId}/delivery-offers/${counter.body.data.id}/select`)
        .set('Authorization', `Bearer ${customer.token}`),
      request(app.getHttpServer()).post(`/v1/food/orders/${orderId}/claim`).set('Authorization', `Bearer ${driverB.token}`),
    ]);
    expect([select.status, claim.status].sort((a, b) => a - b)).toEqual([200, 409]);
    const row = await prisma.db()!.foodOrder.findUniqueOrThrow({ where: { id: orderId } });
    const offers = await prisma.db()!.foodDeliveryOffer.findMany({ where: { orderId } });
    if (select.status === 200) {
      expect(row.assignedDriverId).toBe(driverA.userId);
      expect(row.deliveryFareVnd).toBe(counter.body.data.amountVnd);
      expect(offers[0].status).toBe('SELECTED');
    } else {
      expect(row.assignedDriverId).toBe(driverB.userId);
      expect(row.deliveryFareVnd).toBe(fare);
      expect(offers[0].status).toBe('LOST');
      // The losing counter's driver gets a realtime hint (their offer screen closes).
      const outbox = await prisma.db()!.outboxMessage.findMany({
        where: { aggregateId: orderId, aggregateType: 'FoodOrder' },
      });
      const assigned = outbox.find(
        (m) => (m.payload as Record<string, unknown>)?.assignedDriverId === driverB.userId,
      );
      expect((assigned?.payload as Record<string, unknown>)?.lostDriverIds).toEqual([
        driverA.userId,
      ]);
    }
    expect(row.totalVnd).toBe(row.subtotalVnd + row.deliveryFareVnd - row.discountVnd);
    expect(row.deliveryFareAgreedAt).not.toBeNull();
  });

  it('customer raise vs driver claim: the claim never books a stale fee', async () => {
    const suffix = `${Date.now()}-${randomUUID().slice(0, 8)}`;
    const { customer, driverA, orderId, fare } = await readyOrder(suffix);
    const raised = Math.ceil((fare + 2000) / 1000) * 1000;
    const [raise, claim] = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/food/orders/${orderId}/delivery-fare`)
        .set('Authorization', `Bearer ${customer.token}`)
        .send({ amountVnd: raised }),
      request(app.getHttpServer()).post(`/v1/food/orders/${orderId}/claim`).set('Authorization', `Bearer ${driverA.token}`),
    ]);
    const row = await prisma.db()!.foodOrder.findUniqueOrThrow({ where: { id: orderId } });
    if (claim.status === 200) {
      expect(claim.body.data.deliveryFareVnd).toBe(row.deliveryFareVnd);
    } else {
      expect(raise.status).toBe(200);
      expect(row.deliveryFareVnd).toBe(raised);
    }
    expect(row.totalVnd).toBe(row.subtotalVnd + row.deliveryFareVnd - row.discountVnd);
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
