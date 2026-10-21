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
import { MerchantModule } from '../../../src/modules/merchant/merchant.module.js';
import { MemoryFoodRepository } from '../../../src/modules/food-order/food.repository.js';
import { MemoryDriverPresenceRepository } from '../../../src/modules/identity/driver-presence.repository.js';
import {
  DRIVER_PRESENCE_REPOSITORY,
  IDENTITY_REPOSITORY,
  SMS_SENDER,
} from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';

const OPS_EMAIL = 'ops-directory@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';

describe('ops directory http', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let foods: MemoryFoodRepository;
  let presence: MemoryDriverPresenceRepository;
  let sms: MockSmsSender;
  let opsToken: string;
  let phoneSerial = 700;

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    foods = new MemoryFoodRepository();
    presence = new MemoryDriverPresenceRepository();
    sms = new MockSmsSender('test');

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
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
              PARTNER_ELIGIBILITY_BYPASS: 'true',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        FoodModule,
        MerchantModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .overrideProvider(DRIVER_PRESENCE_REPOSITORY)
      .useValue(presence)
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
    opsToken = loggedIn.body.data.accessToken as string;
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects unauthenticated ops directory reads', async () => {
    await request(app.getHttpServer()).get('/v1/ops/customers').expect(401);
    await request(app.getHttpServer()).get('/v1/ops/drivers').expect(401);
    await request(app.getHttpServer()).get('/v1/ops/stores').expect(401);
  });

  it('lists and details customers with CUSTOMER grants', async () => {
    const customer = await seedUser('CUSTOMER');
    const otherRole = await seedUser('DRIVER');

    const listed = await request(app.getHttpServer())
      .get('/v1/ops/customers?page=1&limit=20')
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);

    expect(listed.body.data).toEqual(
      expect.objectContaining({
        page: 1,
        limit: 20,
        total: expect.any(Number),
        items: expect.any(Array),
      }),
    );
    expect(listed.body.data.items.some((row: { id: string }) => row.id === customer.id)).toBe(
      true,
    );
    expect(listed.body.data.items.some((row: { id: string }) => row.id === otherRole.id)).toBe(
      false,
    );

    const detail = await request(app.getHttpServer())
      .get(`/v1/ops/customers/${customer.id}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);

    expect(detail.body.data).toEqual({
      id: customer.id,
      displayName: expect.any(String),
      phone: customer.phone,
      phoneMasked: expect.any(String),
      email: null,
      phoneVerifiedAt: expect.any(String),
      emailVerifiedAt: null,
      createdAt: expect.any(String),
      grants: [expect.objectContaining({ role: 'CUSTOMER', status: 'ACTIVE' })],
      deletion: null,
    });
    expect(JSON.stringify(detail.body)).not.toMatch(/passwordHash|refreshToken/i);

    await request(app.getHttpServer())
      .get(`/v1/ops/customers/${otherRole.id}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(404);
  });

  it('lists and details drivers with presence summary', async () => {
    const driver = await seedUser('DRIVER');
    await presence.upsert(driver.id, { online: true, lat: 16.05, lng: 108.2 });

    const listed = await request(app.getHttpServer())
      .get('/v1/ops/drivers?page=1&limit=20')
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);

    const row = listed.body.data.items.find((entry: { id: string }) => entry.id === driver.id);
    expect(row).toEqual(
      expect.objectContaining({
        id: driver.id,
        grants: [expect.objectContaining({ role: 'DRIVER', status: 'ACTIVE' })],
        presence: expect.objectContaining({
          online: true,
          lat: 16.05,
          lng: 108.2,
          updatedAt: expect.any(String),
        }),
      }),
    );

    const detail = await request(app.getHttpServer())
      .get(`/v1/ops/drivers/${driver.id}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);
    expect(detail.body.data.presence?.online).toBe(true);
    expect(JSON.stringify(detail.body)).not.toMatch(/passwordHash|refreshToken/i);
  });

  it('lists and details food stores', async () => {
    const merchant = await seedUser('MERCHANT');
    const store = await foods.createStore(merchant.id, 'Ops Cafe', [
      { name: 'Cà phê sữa', priceVnd: 25_000 },
    ]);

    const listed = await request(app.getHttpServer())
      .get('/v1/ops/stores?page=1&limit=20')
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);

    expect(listed.body.data).toEqual(
      expect.objectContaining({
        page: 1,
        limit: 20,
        total: expect.any(Number),
        items: expect.any(Array),
      }),
    );
    expect(listed.body.data.items.some((row: { id: string }) => row.id === store.id)).toBe(true);
    // Admin's sale status comes from these live fields (DEC-PROD-026/027/028); they must survive
    // the ops mapper, not just the repository.
    expect(listed.body.data.items.find((row: { id: string }) => row.id === store.id)).toMatchObject({
      serviceMode: 'OPEN',
      serviceModeUntil: null,
      openNow: true,
      closedReason: null,
      acceptSettings: { acceptMode: 'MANUAL', maxActiveOrders: null, defaultPrepMinutes: 15, busyExtraMinutes: 15 },
      estimatedPrepMinutes: 15,
    });

    const detail = await request(app.getHttpServer())
      .get(`/v1/ops/stores/${store.id}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);

    expect(detail.body.data).toEqual(
      expect.objectContaining({
        id: store.id,
        name: 'Ops Cafe',
        ownerId: merchant.id,
        lat: null,
        lng: null,
        createdAt: expect.any(String),
        itemCount: 1,
        items: [
          expect.objectContaining({
            name: 'Cà phê sữa',
            priceVnd: 25_000,
            available: true,
          }),
        ],
      }),
    );
  });

  async function seedUser(role: 'CUSTOMER' | 'DRIVER' | 'MERCHANT'): Promise<{
    id: string;
    phone: string;
  }> {
    phoneSerial += 1;
    // Created directly: phone OTP sign-up would also add a CUSTOMER grant to every role.
    const user = await identity.createUser({
      phone: `+84901${String(phoneSerial).padStart(6, '0')}`,
      email: null,
      displayName: 'DealGo user',
    });
    await identity.markPhoneVerified(user.id, new Date());
    await identity.insertGrant(user.id, role, 'ACTIVE');
    return { id: user.id, phone: user.phone as string };
  }
});
