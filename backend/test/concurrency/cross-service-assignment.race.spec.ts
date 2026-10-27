/**
 * One driver, two services, one slot.
 *
 * A customer selects driver D's ride offer at the same moment D claims a READY
 * food order. Both paths take pg_advisory_xact_lock('driver-assign:'+D) and count
 * active ride + food jobs inside that lock, so with MAX_CONCURRENT_JOBS_PER_DRIVER=1
 * exactly one must win. Skips when DATABASE_URL is unset.
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
import { RideModule } from '../../src/modules/ride/ride.module.js';
import { FoodModule } from '../../src/modules/food-order/food.module.js';
import { CatalogModule } from '../../src/modules/catalog/catalog.module.js';
import { PARTNER_REPOSITORY } from '../../src/modules/partner/partner.constants.js';
import type { PartnerRepository } from '../../src/modules/partner/partner.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

const pickup = { lat: 10.776889, lng: 106.700806, label: 'District 1' };
const dropoff = { lat: 10.823099, lng: 106.629664, label: 'Airport' };
const foodDropoff = { lat: 16.06, lng: 108.21, label: 'Hải Châu' };
const ROUNDS = 5;

describePg('cross-service driver assignment race (postgres)', () => {
  let app: INestApplication;
  let sms: MockSmsSender;

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
              RIDE_OFFER_TTL_SECONDS: '60',
              FOOD_MIN_DELIVERY_VND: '5000',
              FOOD_MAX_DELIVERY_VND: '100000',
              MAX_CONCURRENT_JOBS_PER_DRIVER: '1',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PrismaModule,
        RideModule,
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
    if (!app.get(PrismaService).db()) {
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

  async function readyFoodOrder(
    customerToken: string,
    merchantToken: string,
    suffix: string,
  ): Promise<string> {
    await request(app.getHttpServer())
      .get('/v1/food/merchant/catalog')
      .set('Authorization', `Bearer ${merchantToken}`)
      .expect(200);
    const item = await request(app.getHttpServer())
      .post('/v1/food/merchant/items')
      .set('Authorization', `Bearer ${merchantToken}`)
      .send({ name: `X-race ${suffix}`, priceVnd: 45_000 })
      .expect(200);
    const catalog = await request(app.getHttpServer())
      .get('/v1/food/merchant/catalog')
      .set('Authorization', `Bearer ${merchantToken}`)
      .expect(200);
    await pinStore(app, merchantToken);
    const placed = await request(app.getHttpServer())
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${customerToken}`)
      .set('Idempotency-Key', `x-race-food-${suffix}`)
      .send({
        storeId: catalog.body.data.id,
        dropoff: foodDropoff,
        deliveryFareVnd: 15_000,
        items: [{ itemId: item.body.data.id, quantity: 1 }],
      });
    if (placed.status !== 200) {
      throw new Error(`place failed ${placed.status}: ${JSON.stringify(placed.body)}`);
    }
    const orderId = placed.body.data.id as string;
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/accept`)
      .set('Authorization', `Bearer ${merchantToken}`)
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/ready`)
      .set('Authorization', `Bearer ${merchantToken}`)
      .expect(200);
    return orderId;
  }

  it(`ride selection vs food claim on the same driver: exactly one wins (${ROUNDS} rounds)`, async () => {
    const identity = app.get(IDENTITY_REPOSITORY);
    const partners = app.get<PartnerRepository>(PARTNER_REPOSITORY);
    const winners: Record<'ride' | 'food', number> = { ride: 0, food: 0 };

    for (let round = 0; round < ROUNDS; round += 1) {
      const customer = await login();
      const merchant = await login();
      const driver = await login();
      await ensureGrant(identity, merchant.userId, 'MERCHANT');
      await ensureGrant(identity, driver.userId, 'DRIVER');
      await partners.upsertSubmit({
        id: randomUUID(),
        userId: driver.userId,
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE' },
        documents: [],
        now: new Date(),
      });
      const suffix = `${Date.now()}-${round}-${randomUUID().slice(0, 8)}`;

      const quote = await request(app.getHttpServer())
        .post('/v1/rides/quote')
        .set('Authorization', `Bearer ${customer.token}`)
        .send({ pickup, dropoff })
        .expect(200);
      const floor = (quote.body.data.options as { code: string; minBidVnd: number }[]).find(
        (o) => o.code === 'MOTORBIKE',
      )!.minBidVnd;
      const ride = await request(app.getHttpServer())
        .post('/v1/rides')
        .set('Authorization', `Bearer ${customer.token}`)
        .set('Idempotency-Key', `x-race-ride-${suffix}`)
        .send({ pickup, dropoff, offeredFareVnd: floor, vehicleClassCode: 'MOTORBIKE' })
        .expect(200);
      const rideId = ride.body.data.id as string;
      const offered = await request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/offers`)
        .set('Authorization', `Bearer ${driver.token}`)
        .send({ amountVnd: floor + 1_000 })
        .expect(200);
      const offerId = (offered.body.data.offers as { id: string; driverId: string }[]).find(
        (o) => o.driverId === driver.userId,
      )!.id;

      const orderId = await readyFoodOrder(customer.token, merchant.token, suffix);

      const [select, claim] = await Promise.all([
        request(app.getHttpServer())
          .post(`/v1/rides/${rideId}/selection`)
          .set('Authorization', `Bearer ${customer.token}`)
          .set('Idempotency-Key', `x-race-select-${suffix}`)
          .send({ offerId }),
        request(app.getHttpServer())
          .post(`/v1/food/orders/${orderId}/claim`)
          .set('Authorization', `Bearer ${driver.token}`),
      ]);

      const statuses = [select.status, claim.status].sort((a, b) => a - b);
      expect(statuses, JSON.stringify({ select: select.body, claim: claim.body })).toEqual([
        200, 409,
      ]);
      winners[select.status === 200 ? 'ride' : 'food'] += 1;

      // Persisted state agrees: the driver holds exactly one active job.
      const rideNow = await request(app.getHttpServer())
        .get(`/v1/rides/${rideId}`)
        .set('Authorization', `Bearer ${customer.token}`)
        .expect(200);
      const foodNow = await request(app.getHttpServer())
        .get(`/v1/food/orders/${orderId}`)
        .set('Authorization', `Bearer ${customer.token}`)
        .expect(200);
      const rideAssigned = rideNow.body.data.status === 'ASSIGNED';
      const foodAssigned = foodNow.body.data.status === 'ASSIGNED';
      expect(Number(rideAssigned) + Number(foodAssigned)).toBe(1);
      expect(rideAssigned).toBe(select.status === 200);
      expect(foodAssigned).toBe(claim.status === 200);
    }

    expect(winners.ride + winners.food).toBe(ROUNDS);
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
