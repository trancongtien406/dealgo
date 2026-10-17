import { randomUUID } from 'node:crypto';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import request from 'supertest';
import { App } from 'supertest/types.js';
import { AppModule } from '../../src/app.module.js';
import type { AppEnv } from '../../src/platform/config/env.js';
import { IDENTITY_REPOSITORY } from '../../src/modules/identity/identity.constants.js';
import {
  MemoryIdentityRepository,
  type IdentityRepository,
} from '../../src/modules/identity/identity.repository.js';
import { FOOD_REPOSITORY } from '../../src/modules/food-order/food.constants.js';
import { MemoryFoodRepository } from '../../src/modules/food-order/food.repository.js';
import { LEDGER_REPOSITORY } from '../../src/modules/ledger/ledger.constants.js';
import { MemoryLedgerRepository } from '../../src/modules/ledger/ledger.repository.js';
import { PAYMENT_REPOSITORY } from '../../src/modules/payment/payment.constants.js';
import { MemoryPaymentRepository } from '../../src/modules/payment/payment.repository.js';
import { PLATFORM_SETTINGS_REPOSITORY } from '../../src/platform/settings/platform-settings.constants.js';
import { MemoryPlatformSettingsRepository } from '../../src/platform/settings/platform-settings.repository.js';
import { accessSecret, signAccessToken } from '../../src/platform/security/token-crypto.js';

describe('Food End-to-End Flow (e2e)', () => {
  let app: INestApplication<App>;
  let identityRepo: IdentityRepository;
  let config: ConfigService<AppEnv, true>;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(new MemoryIdentityRepository())
      .overrideProvider(FOOD_REPOSITORY)
      .useValue(new MemoryFoodRepository())
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(new MemoryPlatformSettingsRepository())
      .overrideProvider(LEDGER_REPOSITORY)
      .useValue(new MemoryLedgerRepository())
      .overrideProvider(PAYMENT_REPOSITORY)
      .useValue(new MemoryPaymentRepository())
      .compile();

    app = moduleFixture.createNestApplication();
    await app.init();

    identityRepo = app.get<IdentityRepository>(IDENTITY_REPOSITORY);
    config = app.get<ConfigService<AppEnv, true>>(ConfigService);
  });

  afterAll(async () => {
    await app.close();
  });

  async function createActor(roles: Array<'CUSTOMER' | 'DRIVER' | 'MERCHANT'>, userId?: string) {
    let user;
    if (userId) {
      user = (await identityRepo.findUserById(userId)) ?? (await identityRepo.createUser({
        email: null,
        phone: `09${Math.floor(10000000 + Math.random() * 90000000)}`,
        displayName: `E2E ${roles.join(',')}`,
      }));
    } else {
      user = await identityRepo.createUser({
        email: null,
        phone: `09${Math.floor(10000000 + Math.random() * 90000000)}`,
        displayName: `E2E ${roles.join(',')}`,
      });
    }

    const existingGrants = await identityRepo.listGrants(user.id);
    for (const role of roles) {
      if (!existingGrants.some((g: { role: string }) => g.role === role)) {
        await identityRepo.insertGrant(user.id, role, 'ACTIVE');
      }
    }
    const session = await identityRepo.createSession({
      userId: user.id,
      familyId: randomUUID(),
      channel: 'CUSTOMER',
      refreshTokenHash: 'hash',
      expiresAt: new Date(Date.now() + 86400_000),
    });
    const secret = accessSecret({
      JWT_ACCESS_SECRET: config.get('JWT_ACCESS_SECRET', { infer: true }),
      NODE_ENV: config.get('NODE_ENV', { infer: true }),
    });
    const token = signAccessToken(
      {
        sub: user.id,
        sid: session.id,
        ch: 'customer',
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 900,
      },
      secret,
    );
    return { user, token };
  }

  it('rejects unauthenticated food order placement with 401', async () => {
    await request(app.getHttpServer())
      .post('/v1/food/orders')
      .send({
        storeId: '00000000-0000-0000-0000-000000000001',
        items: [{ itemId: '00000000-0000-0000-0000-000000000002', quantity: 1 }],
      })
      .expect(401);
  });

  it('completes full food lifecycle: browse store -> place order -> merchant accept -> merchant ready -> driver claim -> driver pickup -> driver deliver', async () => {
    const customer = await createActor(['CUSTOMER']);
    const driver = await createActor(['CUSTOMER', 'DRIVER']);

    // 1. Customer browses stores
    const storesRes = await request(app.getHttpServer())
      .get('/v1/food/stores')
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);

    expect(storesRes.body.data.items.length).toBeGreaterThan(0);
    const store = storesRes.body.data.items[0] as { id: string; name: string; ownerId: string };

    // 2. Customer views store details and catalog items
    const storeDetailRes = await request(app.getHttpServer())
      .get(`/v1/food/stores/${store.id}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);

    const items = storeDetailRes.body.data.items as Array<{ id: string; name: string; priceVnd: number }>;
    expect(items.length).toBeGreaterThan(0);
    const item = items[0];

    // 3. Customer places an order
    const placeRes = await request(app.getHttpServer())
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'idem-e2e-food-lifecycle-001')
      .send({
        storeId: store.id,
        items: [{ itemId: item.id, quantity: 2 }],
        dropoff: { lat: 10.7725, lng: 106.698, label: 'Ben Thanh, District 1' },
      })
      .expect(200);

    expect(placeRes.body.data.status).toBe('PLACED');
    expect(placeRes.body.data.storeId).toBe(store.id);
    const orderId = placeRes.body.data.id as string;

    // 4. Authenticate as merchant (store owner) and accept order
    const merchant = await createActor(['CUSTOMER', 'MERCHANT'], store.ownerId);

    const acceptRes = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/accept`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    expect(acceptRes.body.data.status).toBe('PREPARING');

    // 5. Merchant marks order ready
    const readyRes = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/ready`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    expect(readyRes.body.data.status).toBe('READY');

    // 6. Driver claims ready order
    const claimRes = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/claim`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(claimRes.body.data.status).toBe('ASSIGNED');
    expect(claimRes.body.data.assignedDriverId).toBe(driver.user.id);

    // 7. Driver picks up order
    const pickupRes = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/pickup`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(pickupRes.body.data.status).toBe('PICKED_UP');

    // 8. Driver delivers order
    const deliverRes = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/deliver`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(deliverRes.body.data.status).toBe('DELIVERED');
  });
});
