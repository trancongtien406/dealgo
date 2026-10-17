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
import { FOOD_REPOSITORY } from '../../../src/modules/food-order/food.constants.js';
import { FoodModule } from '../../../src/modules/food-order/food.module.js';
import { MemoryFoodRepository } from '../../../src/modules/food-order/food.repository.js';
import {
  AUTH_METHOD_POLICY_REPOSITORY,
  DRIVER_PRESENCE_REPOSITORY,
  IDENTITY_REPOSITORY,
  MAIL_SENDER,
  SMS_SENDER,
} from '../../../src/modules/identity/identity.constants.js';
import { MemoryAuthMethodPolicyRepository } from '../../../src/modules/identity/auth-method.repository.js';
import { MemoryDriverPresenceRepository } from '../../../src/modules/identity/driver-presence.repository.js';
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
import { MemoryOpsFaqRepository } from '../../../src/modules/support/ops-faq.repository.js';
import { OpsModule } from '../../../src/modules/operations/ops.module.js';
import { ServiceAreaModule } from '../../../src/modules/service-area/service-area.module.js';
import { PaymentModule } from '../../../src/modules/payment/payment.module.js';
import { CatalogModule } from '../../../src/modules/catalog/catalog.module.js';
import { OPS_FAQ_REPOSITORY } from '../../../src/modules/support/support.constants.js';
import { PLATFORM_SETTINGS_REPOSITORY } from '../../../src/platform/settings/platform-settings.constants.js';
import { MemoryPlatformSettingsRepository } from '../../../src/platform/settings/platform-settings.repository.js';

const OPS_EMAIL = 'ops-zones-refunds@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';

class FixedClock implements RideClock {
  constructor(private readonly current: Date) {}
  now(): Date {
    return this.current;
  }
}

describe('ops zones / refunds / catalog categories http', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let foods: MemoryFoodRepository;
  let token: string;

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    foods = new MemoryFoodRepository();
    const settingsRepo = new MemoryPlatformSettingsRepository();
    const faqRepo = new MemoryOpsFaqRepository();
    const policies = new MemoryAuthMethodPolicyRepository();
    const sms = new MockSmsSender('test');
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
              DRIVER_SEARCH_RADIUS_KM: '5',
              RIDE_OFFER_TTL_SECONDS: '60',
              RIDE_MIN_FARE_VND: '10000',
              RIDE_MAX_FARE_VND: '500000',
              RIDE_REFERENCE_VND_PER_KM: '8000',
              FOOD_MIN_DELIVERY_VND: '5000',
              FOOD_MAX_DELIVERY_VND: '100000',
              PARTNER_ELIGIBILITY_BYPASS: 'true',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        OpsModule,
        ServiceAreaModule,
        PaymentModule,
        CatalogModule,
        RideModule,
        FoodModule,
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
      .overrideProvider(DRIVER_PRESENCE_REPOSITORY)
      .useValue(new MemoryDriverPresenceRepository())
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
      .overrideProvider(FOOD_REPOSITORY)
      .useValue(foods)
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

  it('rejects unauthenticated reads', async () => {
    await request(app.getHttpServer()).get('/v1/ops/zones').expect(401);
    await request(app.getHttpServer()).get('/v1/ops/zones/rules').expect(401);
    await request(app.getHttpServer()).get('/v1/ops/refunds').expect(401);
    await request(app.getHttpServer()).get('/v1/ops/catalog/categories').expect(401);
  });

  it('lists zones and pricing rules', async () => {
    const zones = await request(app.getHttpServer())
      .get('/v1/ops/zones')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(zones.body.data.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          name: 'Đà Nẵng',
          status: 'ACTIVE',
          demandCount: expect.any(Number),
        }),
      ]),
    );

    const rules = await request(app.getHttpServer())
      .get('/v1/ops/zones/rules?page=1&limit=10')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(rules.body.data).toEqual(
      expect.objectContaining({
        page: 1,
        limit: 10,
        total: expect.any(Number),
        items: expect.arrayContaining([
          expect.objectContaining({
            code: 'RIDE_MIN_FARE_VND',
            service: 'RIDE',
            unit: 'VND',
            status: 'ACTIVE',
          }),
        ]),
      }),
    );
  });

  it('rejects unauthenticated zone writes', async () => {
    await request(app.getHttpServer()).post('/v1/ops/zones').send({}).expect(401);
    await request(app.getHttpServer()).patch('/v1/ops/zones/DN').send({}).expect(401);
  });

  it('creates, lists, patches and conflicts on admin-managed zones', async () => {
    const auth = { Authorization: `Bearer ${token}` };
    const body = {
      code: 'qni2',
      label: 'Quảng Nam',
      centerLat: 15.57,
      centerLng: 108.47,
      bbox: { minLat: 15.4, maxLat: 15.75, minLng: 108.3, maxLng: 108.7 },
      status: 'ACTIVE',
      reason: 'Mở rộng pilot miền Trung',
    };

    const created = await request(app.getHttpServer())
      .post('/v1/ops/zones')
      .set(auth)
      .send(body)
      .expect(201);
    expect(created.body.data).toEqual(
      expect.objectContaining({ code: 'QNI2', name: 'Quảng Nam', status: 'ACTIVE' }),
    );

    const listed = await request(app.getHttpServer())
      .get('/v1/ops/zones?status=ALL')
      .set(auth)
      .expect(200);
    expect(listed.body.data.items.map((z: { code: string }) => z.code)).toEqual(
      expect.arrayContaining(['DN', 'CT', 'QNI2']),
    );

    await request(app.getHttpServer())
      .post('/v1/ops/zones')
      .set(auth)
      .send(body)
      .expect(409);
    await request(app.getHttpServer())
      .post('/v1/ops/zones')
      .set(auth)
      .send({ ...body, code: 'BAD', centerLat: 99 })
      .expect(400);
    await request(app.getHttpServer())
      .post('/v1/ops/zones')
      .set(auth)
      .send({ ...body, code: 'NOREASON', reason: '' })
      .expect(400);

    const patched = await request(app.getHttpServer())
      .patch('/v1/ops/zones/qni2')
      .set(auth)
      .send({ status: 'PLANNED', reason: 'Tạm dừng khảo sát' })
      .expect(200);
    expect(patched.body.data.status).toBe('PLANNED');

    await request(app.getHttpServer())
      .patch('/v1/ops/zones/NOPE')
      .set(auth)
      .send({ label: 'X Y', reason: 'does not exist' })
      .expect(404);
  });

  it('lists refunds derived from disputes', async () => {
    const listed = await request(app.getHttpServer())
      .get('/v1/ops/refunds?page=1&limit=20')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(listed.body.data).toEqual(
      expect.objectContaining({
        page: 1,
        limit: 20,
        total: expect.any(Number),
        items: expect.any(Array),
      }),
    );
    expect(listed.body.data.total).toBeGreaterThan(0);
    expect(listed.body.data.items[0]).toEqual(
      expect.objectContaining({
        code: expect.stringMatching(/^RF-/),
        orderCode: expect.any(String),
        status: expect.any(String),
      }),
    );
  });

  it('lists catalog categories aggregated from stores', async () => {
    await foods.createFixtureStore('owner-cat', [
      { name: 'Bún bò', priceVnd: 55_000 },
      { name: 'Trà tắc', priceVnd: 20_000 },
    ]);

    const listed = await request(app.getHttpServer())
      .get('/v1/ops/catalog/categories?page=1&limit=20')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(listed.body.data.items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: 'pho',
          name: 'pho',
          slug: 'pho',
          storeCount: 1,
          itemCount: 2,
          status: 'ACTIVE',
        }),
      ]),
    );

    const detail = await request(app.getHttpServer())
      .get('/v1/ops/catalog/categories/pho')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(detail.body.data.code).toBe('pho');

    await request(app.getHttpServer())
      .get('/v1/ops/catalog/categories/missing-cat')
      .set('Authorization', `Bearer ${token}`)
      .expect(404);
  });
});
