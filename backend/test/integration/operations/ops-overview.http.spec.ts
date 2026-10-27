import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { createValidationPipe } from '../../../src/platform/http/create-validation-pipe.js';
import { HttpExceptionFilter } from '../../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../../src/platform/http/response.interceptor.js';
import { loadEnv } from '../../../src/platform/config/env.js';
import {
  IDENTITY_REPOSITORY,
  MAIL_SENDER,
  SMS_SENDER,
} from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { MockMailSender } from '../../../src/integrations/email/mail-sender.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { OpsModule } from '../../../src/modules/operations/ops.module.js';

const OPS_EMAIL = 'ops-overview@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';

describe('ops overview http', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let token: string;

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();

    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              JWT_ACCESS_SECRET: 'test-access-secret',
              JWT_ACCESS_TTL_SECONDS: '900',
              SMS_PROVIDER: 'mock',
              EMAIL_PROVIDER: 'mock',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        OpsModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(new MockSmsSender('test'))
      .overrideProvider(MAIL_SENDER)
      .useValue(new MockMailSender('test'))
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    await app.get(OpsAuthService).ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');

    const loggedIn = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    token = loggedIn.body.data.accessToken as string;
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects unauthenticated overview and monitor snapshot', async () => {
    await request(app.getHttpServer()).get('/v1/ops/overview').expect(401);
    await request(app.getHttpServer()).get('/v1/ops/monitor/snapshot').expect(401);
  });

  it('returns overview KPI shape with numeric money fields', async () => {
    const res = await request(app.getHttpServer())
      .get('/v1/ops/overview')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body.data).toEqual(
      expect.objectContaining({
        ridesTotal: expect.any(Number),
        ridesNegotiating: expect.any(Number),
        ridesAssigned: expect.any(Number),
        ridesCompletedToday: expect.any(Number),
        ridesCancelledToday: expect.any(Number),
        foodOrdersTotal: expect.any(Number),
        foodPlaced: expect.any(Number),
        foodPreparing: expect.any(Number),
        foodInFlight: expect.any(Number),
        foodDeliveredToday: expect.any(Number),
        customersTotal: expect.any(Number),
        driversTotal: expect.any(Number),
        driversOnline: expect.any(Number),
        storesTotal: expect.any(Number),
        exceptionsOpen: expect.any(Number),
        revenueVnd: expect.any(Number),
        commissionVnd: expect.any(Number),
        todayTimezone: 'Asia/Ho_Chi_Minh',
        generatedAt: expect.any(String),
        hourlyTrend: expect.objectContaining({
          buckets: expect.any(Array),
        }),
        recentActivity: expect.any(Array),
        ridesByArea: expect.any(Array),
        foodByCategory: expect.any(Array),
      }),
    );
    expect(res.body.data.hourlyTrend.buckets.length).toBeLessThanOrEqual(24);
    expect(res.body.data.recentActivity.length).toBeLessThanOrEqual(8);
  });

  it('returns a per-day report for a Vietnam day range and validates it', async () => {
    await request(app.getHttpServer()).get('/v1/ops/reports').expect(401);
    const admin = token;

    const res = await request(app.getHttpServer())
      .get('/v1/ops/reports?from=2026-10-01&to=2026-10-03')
      .set('Authorization', `Bearer ${admin}`)
      .expect(200);
    expect(res.body.data).toEqual(
      expect.objectContaining({
        from: '2026-10-01',
        to: '2026-10-03',
        timezone: 'Asia/Ho_Chi_Minh',
        totals: expect.objectContaining({
          ridesCompleted: expect.any(Number),
          revenueVnd: expect.any(Number),
          commissionVnd: expect.any(Number),
        }),
      }),
    );
    expect(res.body.data.daily.map((d: { day: string }) => d.day)).toEqual([
      '2026-10-01',
      '2026-10-02',
      '2026-10-03',
    ]);

    await request(app.getHttpServer())
      .get('/v1/ops/reports?from=2026-10-05&to=2026-10-01')
      .set('Authorization', `Bearer ${admin}`)
      .expect(400);
    await request(app.getHttpServer())
      .get('/v1/ops/reports?from=yesterday')
      .set('Authorization', `Bearer ${admin}`)
      .expect(400);
  });

  it('returns monitor snapshot shape', async () => {
    const res = await request(app.getHttpServer())
      .get('/v1/ops/monitor/snapshot')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body.data).toEqual(
      expect.objectContaining({
        ridesOpen: expect.any(Number),
        ridesNegotiating: expect.any(Number),
        foodReady: expect.any(Number),
        foodInFlight: expect.any(Number),
        driversOnline: expect.any(Number),
        exceptionsOpen: expect.any(Number),
        generatedAt: expect.any(String),
        mapMarkers: expect.any(Array),
        queue: expect.any(Array),
        areaDemand: expect.any(Array),
        recentActivity: expect.any(Array),
        systemAlerts: expect.any(Array),
      }),
    );
    expect(res.body.data.queue.length).toBeGreaterThanOrEqual(4);
    expect(res.body.data.recentActivity.length).toBeLessThanOrEqual(10);
  });
});
