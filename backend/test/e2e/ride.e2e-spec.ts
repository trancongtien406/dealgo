import { MemoryRidePickupCodeStore, RIDE_PICKUP_CODE_STORE } from '../../src/modules/ride/ride-pickup-code.js';
import { randomUUID } from 'node:crypto';
import { EARNINGS_REPOSITORY, MemoryEarningsRepository } from '../../src/modules/earnings/index.js';
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
import { PARTNER_REPOSITORY } from '../../src/modules/partner/partner.constants.js';
import { MemoryPartnerRepository } from '../../src/modules/partner/partner.repository.js';
import { RIDE_REPOSITORY } from '../../src/modules/ride/ride.constants.js';
import { MemoryRideRepository } from '../../src/modules/ride/ride.repository.js';
import { LEDGER_REPOSITORY } from '../../src/modules/ledger/ledger.constants.js';
import { MemoryLedgerRepository } from '../../src/modules/ledger/ledger.repository.js';
import { PAYMENT_REPOSITORY } from '../../src/modules/payment/payment.constants.js';
import { MemoryPaymentRepository } from '../../src/modules/payment/payment.repository.js';
import { PLATFORM_SETTINGS_REPOSITORY } from '../../src/platform/settings/platform-settings.constants.js';
import { MemoryPlatformSettingsRepository } from '../../src/platform/settings/platform-settings.repository.js';
import { accessSecret, signAccessToken } from '../../src/platform/security/token-crypto.js';

describe('Ride End-to-End Flow (e2e)', () => {
  let app: INestApplication<App>;
  let identityRepo: IdentityRepository;
  let config: ConfigService<AppEnv, true>;

  beforeAll(async () => {
    // Code confirmation is off by default since 0d21c55 (2026-10-29); this flow exercises the
    // code path, so turn it on for this suite.
    const settingsRepo = new MemoryPlatformSettingsRepository();
    await settingsRepo.upsert({
      key: 'RIDE_PICKUP_CODE_REQUIRED',
      value: 'true',
      valueType: 'json',
      updatedByUserId: null,
      reason: 'e2e exercises the code path',
      previousValue: null,
    });
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(new MemoryIdentityRepository())
      .overrideProvider(RIDE_REPOSITORY)
      .useValue(new MemoryRideRepository())
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(settingsRepo)
      .overrideProvider(RIDE_PICKUP_CODE_STORE)
      .useValue(new MemoryRidePickupCodeStore())
      .overrideProvider(EARNINGS_REPOSITORY)
      .useValue(new MemoryEarningsRepository())
      .overrideProvider(LEDGER_REPOSITORY)
      .useValue(new MemoryLedgerRepository())
      .overrideProvider(PAYMENT_REPOSITORY)
      .useValue(new MemoryPaymentRepository())
      .overrideProvider(PARTNER_REPOSITORY)
      .useValue(new MemoryPartnerRepository())
      .compile();

    app = moduleFixture.createNestApplication();
    await app.init();

    identityRepo = app.get<IdentityRepository>(IDENTITY_REPOSITORY);
    config = app.get<ConfigService<AppEnv, true>>(ConfigService);
  });

  afterAll(async () => {
    await app.close();
  });

  async function createActor(roles: Array<'CUSTOMER' | 'DRIVER' | 'MERCHANT'>) {
    const user = await identityRepo.createUser({
      email: null,
      phone: `09${Math.floor(10000000 + Math.random() * 90000000)}`,
      displayName: `E2E ${roles.join(',')}`,
    });
    for (const role of roles) {
      await identityRepo.insertGrant(user.id, role, 'ACTIVE');
    }
    if (roles.includes('DRIVER')) {
      // DG-DEC-VEH-001: offers fail closed without a DRIVER application carrying the class.
      await app.get(PARTNER_REPOSITORY).upsertSubmit({
        id: randomUUID(),
        userId: user.id,
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE' },
        documents: [],
        now: new Date(),
      });
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

  it('rejects unauthenticated ride creation with 401', async () => {
    await request(app.getHttpServer())
      .post('/v1/rides')
      .send({
        pickup: { lat: 10.7769, lng: 106.7009, label: 'Ben Thanh' },
        dropoff: { lat: 10.7725, lng: 106.698, label: 'Bitexco' },
        offeredFareVnd: 25000,
        vehicleClassCode: 'MOTORBIKE',
      })
      .expect(401);
  });

  it('rejects a bid above the configured ceiling (DEC-PROD-069 band) with 400', async () => {
    const customer = await createActor(['CUSTOMER']);
    const res = await request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'idem-e2e-ride-out-of-band-001')
      .send({
        pickup: { lat: 10.7769, lng: 106.7009, label: 'Ben Thanh' },
        dropoff: { lat: 10.7725, lng: 106.698, label: 'Bitexco' },
        // ~0.6 km trip: reference = min fare 10,000; ceiling 130% = 13,000.
        offeredFareVnd: 25000,
        vehicleClassCode: 'MOTORBIKE',
      })
      .expect(400);
    expect(res.body.errorCode).toBe('RIDE_FARE_OUT_OF_RANGE');
  });

  it('completes full ride lifecycle: create negotiation -> driver counter offer -> customer select -> assigned -> driver en-route -> arrived -> in-trip -> completed', async () => {
    const customer = await createActor(['CUSTOMER']);
    const driver = await createActor(['CUSTOMER', 'DRIVER']);

    // 1. Customer creates a ride
    const createRes = await request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'idem-e2e-ride-lifecycle-001')
      .send({
        pickup: { lat: 10.7769, lng: 106.7009, label: 'Ben Thanh' },
        dropoff: { lat: 10.7725, lng: 106.698, label: 'Bitexco' },
        offeredFareVnd: 12000, // within the 70–130% band of the 10,000 reference
        vehicleClassCode: 'MOTORBIKE',
      })
      .expect(200);
    expect(createRes.body.data.status).toBe('NEGOTIATING');
    expect(createRes.body.data.offeredFareVnd).toBe(12000);
    const rideId = createRes.body.data.id as string;

    // 2. Driver sends a counter-offer
    const offerRes = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 13000 })
      .expect(200);

    expect(offerRes.body.data.offers).toHaveLength(1);
    const offerId = offerRes.body.data.offers[0].id as string;

    // 3. Customer selects the counter-offer (assigned)
    const selectRes = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'idem-e2e-ride-select-001')
      .send({ offerId })
      .expect(200);

    expect(selectRes.body.data.status).toBe('ASSIGNED');
    expect(selectRes.body.data.assignedDriverId).toBe(driver.user.id);
    expect(selectRes.body.data.agreedFareVnd).toBe(13000);

    // 4. Driver marks en route
    const enRouteRes = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/en-route`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(enRouteRes.body.data.status).toBe('DRIVER_EN_ROUTE');

    // 5. Driver marks arrived
    const arrivedRes = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/arrived`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(arrivedRes.body.data.status).toBe('DRIVER_ARRIVED');

    // 6. Customer reads the server-issued pickup code; driver starts trip with it
    const customerView = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    const pickupCode = customerView.body.data.pickupCode as string;
    expect(pickupCode).toMatch(/^\d{4}$/);
    const startRes = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/start`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ pickupCode })
      .expect(200);
    expect(startRes.body.data.status).toBe('IN_TRIP');

    // 7. Driver completes trip
    const completeRes = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/complete`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(completeRes.body.data.status).toBe('COMPLETED');
  });
});
