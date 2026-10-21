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
import { MemoryAuthMethodPolicyRepository } from '../../../src/modules/identity/auth-method.repository.js';
import { MemoryDriverPresenceRepository } from '../../../src/modules/identity/driver-presence.repository.js';
import {
  AUTH_METHOD_POLICY_REPOSITORY,
  DRIVER_PRESENCE_REPOSITORY,
  IDENTITY_REPOSITORY,
  MAIL_SENDER,
  SMS_SENDER,
} from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { MockMailSender } from '../../../src/integrations/email/mail-sender.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { LEDGER_REPOSITORY } from '../../../src/modules/ledger/ledger.constants.js';
import { MemoryLedgerRepository } from '../../../src/modules/ledger/ledger.repository.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import { MemoryPartnerRepository } from '../../../src/modules/partner/partner.repository.js';
import { PAYMENT_REPOSITORY } from '../../../src/modules/payment/payment.constants.js';
import { MemoryPaymentRepository } from '../../../src/modules/payment/payment.repository.js';
import { RIDE_CLOCK, RIDE_REPOSITORY, type RideClock } from '../../../src/modules/ride/ride.constants.js';
import { RideModule } from '../../../src/modules/ride/ride.module.js';
import { MemoryRideRepository } from '../../../src/modules/ride/ride.repository.js';
import { OPS_FAQ_SEEDS } from '../../../src/modules/support/ops-faq.seed.js';
import { MemoryOpsFaqRepository } from '../../../src/modules/support/ops-faq.repository.js';
import { OpsModule } from '../../../src/modules/operations/ops.module.js';
import { OPS_FAQ_REPOSITORY } from '../../../src/modules/support/support.constants.js';
import { PLATFORM_SETTINGS_REPOSITORY } from '../../../src/platform/settings/platform-settings.constants.js';
import { MemoryPlatformSettingsRepository } from '../../../src/platform/settings/platform-settings.repository.js';
import { PlatformSettingsService } from '../../../src/platform/settings/platform-settings.service.js';

const OPS_EMAIL = 'ops-settings@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';

class FixedClock implements RideClock {
  constructor(private readonly current: Date) {}
  now(): Date {
    return this.current;
  }
}

describe('ops platform settings + faqs http', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let settingsRepo: MemoryPlatformSettingsRepository;
  let faqRepo: MemoryOpsFaqRepository;
  let sms: MockSmsSender;
  let token: string;
  let phoneSerial = 400;

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    settingsRepo = new MemoryPlatformSettingsRepository();
    faqRepo = new MemoryOpsFaqRepository();
    const policies = new MemoryAuthMethodPolicyRepository();
    sms = new MockSmsSender('test');
    const mail = new MockMailSender('test');
    const clock = new FixedClock(new Date('2026-10-14T12:00:00.000Z'));

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
              WEBAUTHN_RP_ID: 'localhost',
              WEBAUTHN_RP_NAME: 'DealGo',
              WEBAUTHN_ORIGIN: 'http://localhost:3000',
              SMS_PROVIDER: 'mock',
              EMAIL_PROVIDER: 'mock',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
              DRIVER_SEARCH_RADIUS_KM: '5',
              RIDE_OFFER_TTL_SECONDS: '60',
              RIDE_MIN_FARE_VND: '10000',
              RIDE_MAX_FARE_VND: '500000',
              RIDE_REFERENCE_VND_PER_KM: '8000',
              PARTNER_ELIGIBILITY_BYPASS: 'true',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        OpsModule,
        RideModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(MAIL_SENDER)
      .useValue(mail)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .overrideProvider(AUTH_METHOD_POLICY_REPOSITORY)
      .useValue(policies)
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(settingsRepo)
      .overrideProvider(OPS_FAQ_REPOSITORY)
      .useValue(faqRepo)
      .overrideProvider(RIDE_REPOSITORY)
      .useValue(new MemoryRideRepository())
      .overrideProvider(RIDE_CLOCK)
      .useValue(clock)
      .overrideProvider(LEDGER_REPOSITORY)
      .useValue(new MemoryLedgerRepository())
      .overrideProvider(PARTNER_REPOSITORY)
      .useValue(new MemoryPartnerRepository())
      .overrideProvider(PAYMENT_REPOSITORY)
      .useValue(new MemoryPaymentRepository())
      .overrideProvider(DRIVER_PRESENCE_REPOSITORY)
      .useValue(new MemoryDriverPresenceRepository())
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

  it('lists settings seeded from env bootstrap', async () => {
    const listed = await request(app.getHttpServer())
      .get('/v1/ops/platform-settings')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const keys = (listed.body.data as Array<{ key: string }>).map((r) => r.key);
    expect(keys).toContain('DRIVER_SEARCH_RADIUS_KM');
    expect(keys).toContain('PAYMENT_METHODS_ENABLED');
    expect(keys).not.toContain('PILOT_ZONE_LABEL');
    expect(keys).toContain('MAX_CONCURRENT_JOBS_PER_DRIVER');
    const radius = listed.body.data.find(
      (r: { key: string }) => r.key === 'DRIVER_SEARCH_RADIUS_KM',
    );
    expect(radius.value).toBe('5');
  });

  it('filters settings by category, source, and search query', async () => {
    const fareRes = await request(app.getHttpServer())
      .get('/v1/ops/platform-settings?category=FARE')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const fareKeys = (fareRes.body.data as Array<{ key: string }>).map((r) => r.key);
    expect(fareKeys).toContain('RIDE_MIN_FARE_VND');
    expect(fareKeys).not.toContain('DRIVER_SEARCH_RADIUS_KM');

    const searchRes = await request(app.getHttpServer())
      .get('/v1/ops/platform-settings?q=RADIUS')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const searchKeys = (searchRes.body.data as Array<{ key: string }>).map((r) => r.key);
    expect(searchKeys).toEqual(['DRIVER_SEARCH_RADIUS_KM']);
  });


  it('patches a setting and records last-write audit', async () => {
    const patched = await request(app.getHttpServer())
      .patch('/v1/ops/platform-settings/DRIVER_SEARCH_RADIUS_KM')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: '12', reason: 'pilot denser supply TEST_ONLY' })
      .expect(200);

    expect(patched.body.data).toEqual(
      expect.objectContaining({
        key: 'DRIVER_SEARCH_RADIUS_KM',
        value: '12',
        source: 'db',
      }),
    );

    expect(settingsRepo.audits.at(-1)).toEqual(
      expect.objectContaining({
        action: 'SETTINGS_UPDATE',
        reason: 'pilot denser supply TEST_ONLY',
        metadata: expect.objectContaining({
          key: 'DRIVER_SEARCH_RADIUS_KM',
          value: '12',
          previousValue: '5',
        }),
      }),
    );

    const resolved = await app.get(PlatformSettingsService).getNumber('DRIVER_SEARCH_RADIUS_KM');
    expect(resolved).toBe(12);
  });

  it('seeds platform fees and the rating window, and validates fee percents', async () => {
    const listed = await request(app.getHttpServer())
      .get('/v1/ops/platform-settings?category=FARE')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const byKey = new Map(
      (listed.body.data as Array<{ key: string; value: string }>).map((r) => [r.key, r.value]),
    );
    expect(byKey.get('PLATFORM_FEE_RIDE_PERCENT')).toBe('0');
    expect(byKey.get('PLATFORM_FEE_FOOD_PERCENT')).toBe('0');
    const service = app.get(PlatformSettingsService);
    expect(await service.getNumber('RATING_WINDOW_DAYS')).toBe(7);

    const patch = (key: string, value: string) =>
      request(app.getHttpServer())
        .patch(`/v1/ops/platform-settings/${key}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ value, reason: 'fee policy TEST_ONLY' });
    for (const bad of ['-1', '100.5', '12.345', 'abc', '1e1']) {
      const res = await patch('PLATFORM_FEE_RIDE_PERCENT', bad).expect(400);
      expect(res.body.errorCode).toBe('PLATFORM_SETTING_INVALID');
    }
    await patch('RATING_WINDOW_DAYS', '2.5').expect(400);
    await patch('RATING_WINDOW_DAYS', '0').expect(400);

    const ok = await patch('PLATFORM_FEE_RIDE_PERCENT', '12.50').expect(200);
    expect(ok.body.data).toMatchObject({ value: '12.5', source: 'db' });
    expect(settingsRepo.audits.at(-1)).toEqual(
      expect.objectContaining({
        reason: 'fee policy TEST_ONLY',
        metadata: expect.objectContaining({
          key: 'PLATFORM_FEE_RIDE_PERCENT',
          value: '12.5',
          previousValue: '0',
        }),
      }),
    );
    expect(await service.getNumber('PLATFORM_FEE_RIDE_PERCENT')).toBe(12.5);
    await patch('RATING_WINDOW_DAYS', '14').expect(200);
    expect(await service.getNumber('RATING_WINDOW_DAYS')).toBe(14);
  });

  it('seeds and validates the upload limits (DEC-PROD-020)', async () => {
    const service = app.get(PlatformSettingsService);
    expect(await service.getNumber('UPLOAD_MAX_FILE_KB')).toBe(4096);
    expect(await service.getJson('UPLOAD_ALLOWED_TYPES')).toEqual([
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
    ]);
    const patch = (key: string, value: string) =>
      request(app.getHttpServer())
        .patch(`/v1/ops/platform-settings/${key}`)
        .set('Authorization', `Bearer ${token}`)
        .send({ value, reason: 'upload policy TEST_ONLY' });
    await patch('UPLOAD_MAX_FILE_KB', '99').expect(400);
    await patch('UPLOAD_MAX_FILE_KB', '5121').expect(400);
    for (const bad of ['[]', '["image/svg+xml"]', '["image/jpeg","image/jpeg"]', '"image/jpeg"']) {
      const res = await patch('UPLOAD_ALLOWED_TYPES', bad).expect(400);
      expect(res.body.errorCode).toBe('PLATFORM_SETTING_INVALID');
    }
    await patch('UPLOAD_ALLOWED_TYPES', '["image/jpeg","application/pdf"]').expect(200);
    expect(await service.getJson('UPLOAD_ALLOWED_TYPES')).toEqual(['image/jpeg', 'application/pdf']);
    await patch('UPLOAD_MAX_FILE_KB', '2048').expect(200);
    expect(await service.getNumber('UPLOAD_MAX_FILE_KB')).toBe(2048);
  });

  it('lists FAQ drafts for OPEN-001..021 and allows create', async () => {
    const listed = await request(app.getHttpServer())
      .get('/v1/ops/faqs')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const internal = listed.body.data.filter((f: { audience: string }) => f.audience === 'INTERNAL');
    expect(internal).toHaveLength(OPS_FAQ_SEEDS.length);
    expect(
      listed.body.data.filter((f: { audience: string }) => f.audience === 'CUSTOMER').length,
    ).toBeGreaterThanOrEqual(5);
    const help = await request(app.getHttpServer()).get('/v1/public/help/faqs').expect(200);
    expect(help.body.data[0]).toEqual({
      id: expect.any(String),
      question: expect.any(String),
      answer: expect.any(String),
      updatedAt: expect.any(String),
    });
    expect(help.body.data.every((f: { question: string }) => !f.question.includes('pilot'))).toBe(true);
    await request(app.getHttpServer()).get('/v1/public/help/faqs?audience=INTERNAL').expect(400);
    expect(listed.body.data[0]).toEqual(
      expect.objectContaining({
        openId: 'OPEN-001',
        status: 'DRAFT',
      }),
    );
    expect(listed.body.data[0].suggestedAnswer).toContain('PROPOSED');

    const created = await request(app.getHttpServer())
      .post('/v1/ops/faqs')
      .set('Authorization', `Bearer ${token}`)
      .send({
        question: 'General ops note?',
        suggestedAnswer: '**PROPOSED:** Owner decides.',
        category: 'OPS',
        reason: 'add general draft',
      })
      .expect(201);

    expect(created.body.data.status).toBe('DRAFT');
    expect(faqRepo.audits.at(-1)).toEqual(
      expect.objectContaining({
        action: 'FAQ_UPDATE',
        reason: 'add general draft',
      }),
    );
  });

  it('ride listOpen uses patched DRIVER_SEARCH_RADIUS_KM', async () => {
    await request(app.getHttpServer())
      .patch('/v1/ops/platform-settings/DRIVER_SEARCH_RADIUS_KM')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: '1', reason: 'tighten radius for test' })
      .expect(200);
    app.get(PlatformSettingsService).invalidateCache();

    const customerNear = await loginUser();
    const customerFar = await loginUser();
    const driver = await loginUser();
    await identity.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');

    const origin = { lat: 16.0544, lng: 108.2022, label: 'DN center' };
    const nearDrop = { lat: 16.055, lng: 108.203, label: 'near' };
    const farPickup = { lat: 16.1, lng: 108.3, label: 'far' };
    const farDrop = { lat: 16.11, lng: 108.31, label: 'far-drop' };

    await request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customerNear.token}`)
      .set('Idempotency-Key', `radius-near-${Date.now()}`)
      .send({ pickup: origin, dropoff: nearDrop, offeredFareVnd: 30_000 })
      .expect(200);

    await request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customerFar.token}`)
      .set('Idempotency-Key', `radius-far-${Date.now()}`)
      .send({ pickup: farPickup, dropoff: farDrop, offeredFareVnd: 30_000 })
      .expect(200);

    await request(app.getHttpServer())
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ online: true, lat: origin.lat, lng: origin.lng })
      .expect(200);

    const open = await request(app.getHttpServer())
      .get('/v1/rides/open')
      .query({ lat: origin.lat, lng: origin.lng })
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);

    const pickups = (open.body.data as Array<{ pickup: { label: string } }>).map(
      (r) => r.pickup.label,
    );
    expect(pickups).toContain('DN center');
    expect(pickups).not.toContain('far');
  });

  async function loginUser(): Promise<{ token: string; userId: string }> {
    phoneSerial += 1;
    const phone = `091${String(phoneSerial).padStart(7, '0')}`;
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
});
