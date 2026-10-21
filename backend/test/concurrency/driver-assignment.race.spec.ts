/**
 * Concurrent ride selection against Postgres.
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
import { RIDE_CLOCK, type RideClock } from '../../src/modules/ride/ride.constants.js';
import { RideModule } from '../../src/modules/ride/ride.module.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

const CLOCK_START = new Date('2026-10-14T12:00:00.000Z');
const pickup = { lat: 10.776889, lng: 106.700806, label: 'District 1' };
const dropoff = { lat: 10.823099, lng: 106.629664, label: 'Airport' };

class ManualClock implements RideClock {
  constructor(private current: Date) {}
  now(): Date {
    return this.current;
  }
}

describePg('ride select race (postgres)', () => {
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
              RIDE_OFFER_TTL_SECONDS: '60',
              RIDE_MIN_FARE_VND: '10000',
              RIDE_MAX_FARE_VND: '500000',
              RIDE_REFERENCE_VND_PER_KM: '8000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PrismaModule,
        RideModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(RIDE_CLOCK)
      .useValue(new ManualClock(CLOCK_START))
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
    const phone = uniqueTestPhone('098');
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

  it('lets only one of two racing selections win against Postgres', async () => {
    const customer = await login();
    const driverA = await login();
    const driverB = await login();
    const identity = app.get(IDENTITY_REPOSITORY);
    await ensureGrant(identity, driverA.userId, 'DRIVER');
    await ensureGrant(identity, driverB.userId, 'DRIVER');

    const suffix = `${Date.now()}-${randomUUID().slice(0, 8)}`;
    const created = await request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `pg-race-create-${suffix}`)
      .send({ pickup, dropoff, offeredFareVnd: 30_000 })
      .expect(200);
    const rideId = created.body.data.id as string;

    const offerA = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driverA.token}`)
      .send({ amountVnd: 40_000 })
      .expect(200);
    const offerB = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driverB.token}`)
      .send({ amountVnd: 42_000 })
      .expect(200);
    const offerAId = offerA.body.data.offers.find(
      (item: { driverId: string }) => item.driverId === driverA.userId,
    ).id as string;
    const offerBId = offerB.body.data.offers.find(
      (item: { driverId: string }) => item.driverId === driverB.userId,
    ).id as string;

    const [first, second] = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/selection`)
        .set('Authorization', `Bearer ${customer.token}`)
        .set('Idempotency-Key', `pg-race-a-${suffix}`)
        .send({ offerId: offerAId }),
      request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/selection`)
        .set('Authorization', `Bearer ${customer.token}`)
        .set('Idempotency-Key', `pg-race-b-${suffix}`)
        .send({ offerId: offerBId }),
    ]);

    const statuses = [first.status, second.status].sort((a, b) => a - b);
    expect(statuses).toEqual([200, 409]);
    const success = first.status === 200 ? first : second;
    expect(success.body.data.status).toBe('ASSIGNED');
  });
});

async function ensureGrant(
  identity: {
    insertGrant: (userId: string, role: 'DRIVER', status: 'ACTIVE') => Promise<unknown>;
  },
  userId: string,
  role: 'DRIVER',
): Promise<void> {
  try {
    await identity.insertGrant(userId, role, 'ACTIVE');
  } catch (error) {
    if (!(error instanceof UniqueConflictError)) {
      throw error;
    }
  }
}
