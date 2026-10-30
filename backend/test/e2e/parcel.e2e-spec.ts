import { randomUUID } from 'node:crypto';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import request from 'supertest';
import { App } from 'supertest/types.js';
import { AppModule } from '../../src/app.module.js';
import type { AppEnv } from '../../src/platform/config/env.js';
import { DRIVER_PRESENCE_REPOSITORY, IDENTITY_REPOSITORY } from '../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository, type IdentityRepository } from '../../src/modules/identity/identity.repository.js';
import { MemoryDriverPresenceRepository } from '../../src/modules/identity/driver-presence.repository.js';
import { PARTNER_REPOSITORY } from '../../src/modules/partner/partner.constants.js';
import { MemoryPartnerRepository } from '../../src/modules/partner/partner.repository.js';
import { RIDE_REPOSITORY } from '../../src/modules/ride/ride.constants.js';
import { MemoryRideRepository } from '../../src/modules/ride/ride.repository.js';
import { MemoryRidePickupCodeStore, RIDE_PICKUP_CODE_STORE } from '../../src/modules/ride/ride-pickup-code.js';
import { MemoryRideParcelStore, RIDE_PARCEL_STORE } from '../../src/modules/ride/ride-parcel.store.js';
import { EARNINGS_REPOSITORY, MemoryEarningsRepository } from '../../src/modules/earnings/index.js';
import { LEDGER_REPOSITORY } from '../../src/modules/ledger/ledger.constants.js';
import { MemoryLedgerRepository } from '../../src/modules/ledger/ledger.repository.js';
import { PAYMENT_REPOSITORY } from '../../src/modules/payment/payment.constants.js';
import { MemoryPaymentRepository } from '../../src/modules/payment/payment.repository.js';
import { PLATFORM_SETTINGS_REPOSITORY } from '../../src/platform/settings/platform-settings.constants.js';
import { MemoryPlatformSettingsRepository } from '../../src/platform/settings/platform-settings.repository.js';
import { RIDE_VEHICLE_CLASS_REPOSITORY } from '../../src/modules/ride-vehicle/ride-vehicle-class.constants.js';
import { MemoryRideVehicleClassRepository } from '../../src/modules/ride-vehicle/ride-vehicle-class.repository.js';
import { RideVehicleClassService } from '../../src/modules/ride-vehicle/ride-vehicle-class.service.js';
import { accessSecret, signAccessToken } from '../../src/platform/security/token-crypto.js';

// 1x1 PNG
const PHOTO = {
  contentType: 'image/png',
  contentBase64:
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
};
const PICKUP = { lat: 10.7769, lng: 106.7009, label: 'Ben Thanh' };
const DROPOFF = { lat: 10.7725, lng: 106.698, label: 'Bitexco' };

describe('Parcel delivery (DEC-PROD-071) e2e', () => {
  let app: INestApplication<App>;
  let identityRepo: IdentityRepository;
  let config: ConfigService<AppEnv, true>;
  const settingsRepo = new MemoryPlatformSettingsRepository();
  const vehicleRepo = new MemoryRideVehicleClassRepository();
  const presenceRepo = new MemoryDriverPresenceRepository();
  const rideRepo = new MemoryRideRepository();

  beforeAll(async () => {
    await settingsRepo.upsert({
      key: 'PARCEL_RECIPIENT_CODE_REQUIRED',
      value: 'true',
      valueType: 'json',
      updatedByUserId: null,
      reason: 'e2e exercises the recipient code',
      previousValue: null,
    });
    await settingsRepo.upsert({
      key: 'PARCEL_SERVICE_FEE_VND',
      value: '1000',
      valueType: 'number',
      updatedByUserId: null,
      reason: 'e2e exercises the parcel service fee',
      previousValue: null,
    });
    const moduleFixture: TestingModule = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(new MemoryIdentityRepository())
      .overrideProvider(RIDE_REPOSITORY)
      .useValue(rideRepo)
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(settingsRepo)
      .overrideProvider(RIDE_PICKUP_CODE_STORE)
      .useValue(new MemoryRidePickupCodeStore())
      .overrideProvider(RIDE_PARCEL_STORE)
      .useValue(new MemoryRideParcelStore())
      .overrideProvider(RIDE_VEHICLE_CLASS_REPOSITORY)
      .useValue(vehicleRepo)
      .overrideProvider(DRIVER_PRESENCE_REPOSITORY)
      .useValue(presenceRepo)
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
    await app.get(RideVehicleClassService).listEnabled(); // seeds the catalog
    await vehicleRepo.update('MOTORBIKE', { parcelEnabled: true }, 'e2e');
  });

  afterAll(async () => {
    await app.close();
  });

  async function actor(roles: Array<'CUSTOMER' | 'DRIVER'>) {
    const user = await identityRepo.createUser({
      email: null,
      phone: `09${Math.floor(10000000 + Math.random() * 90000000)}`,
      displayName: `E2E ${roles.join(',')}`,
    });
    for (const role of roles) await identityRepo.insertGrant(user.id, role, 'ACTIVE');
    if (roles.includes('DRIVER')) {
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
    const now = Math.floor(Date.now() / 1000);
    const token = signAccessToken({ sub: user.id, sid: session.id, ch: 'customer', iat: now, exp: now + 900 }, secret);
    return { user, token };
  }

  const http = () => request(app.getHttpServer());

  function book(token: string, key: string, extra: Record<string, unknown> = {}) {
    return http()
      .post('/v1/parcels')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', key)
      .send({
        pickup: PICKUP,
        dropoff: DROPOFF,
        sizeClass: 'S',
        weightKg: 2,
        offeredFareVnd: 12000,
        vehicleClassCode: 'MOTORBIKE',
        sender: { name: 'Người gửi', phone: '0901234567' },
        recipient: { name: 'Người nhận', phone: '0907654321' },
        note: 'Hộp giày',
        itemPhoto: PHOTO,
        ...extra,
      });
  }

  async function assigned(customer: { token: string }, driver: { token: string }, key: string) {
    const created = await book(customer.token, key).expect(200);
    const rideId = created.body.data.id as string;
    const offer = await http()
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 12000 })
      .expect(200);
    await http()
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `${key}-select`)
      .send({ offerId: offer.body.data.offers[0].id })
      .expect(200);
    await http().post(`/v1/rides/${rideId}/en-route`).set('Authorization', `Bearer ${driver.token}`).expect(200);
    await http().post(`/v1/rides/${rideId}/arrived`).set('Authorization', `Bearer ${driver.token}`).expect(200);
    return { rideId, created };
  }

  it('lists size classes and quotes only parcel-enabled classes with the surcharge', async () => {
    const customer = await actor(['CUSTOMER']);
    const sizes = await http().get('/v1/parcels/size-classes').set('Authorization', `Bearer ${customer.token}`).expect(200);
    expect(sizes.body.data.map((s: { code: string }) => s.code)).toEqual(['S', 'M', 'L', 'XL']);
    const quote = await http()
      .post('/v1/parcels/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ pickup: PICKUP, dropoff: DROPOFF, sizeClass: 'L' })
      .expect(200);
    expect(quote.body.data.options.map((o: { code: string }) => o.code)).toEqual(['MOTORBIKE']);
    expect(quote.body.data.options[0].parcelSurchargeVnd).toBe(10000);
    expect(quote.body.data.options[0].parcelServiceFeeVnd).toBe(1000);
    expect(quote.body.data.options[0].parcelReturnFeeVnd).toBe(10000);
    // XL is cars only and no car class has parcel delivery on.
    const xl = await http()
      .post('/v1/parcels/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ pickup: PICKUP, dropoff: DROPOFF, sizeClass: 'XL' })
      .expect(400);
    expect(xl.body.errorCode).toBe('PARCEL_NO_VEHICLE');
  });

  it('rejects overweight packages and recipient-pays with a non-cash method', async () => {
    const customer = await actor(['CUSTOMER']);
    const heavy = await book(customer.token, 'idem-parcel-heavy-0001', { weightKg: 9 }).expect(400);
    expect(heavy.body.errorCode).toBe('PARCEL_TOO_HEAVY');
    const payer = await book(customer.token, 'idem-parcel-payer-0001', { payer: 'RECIPIENT', paymentMethod: 'WALLET' });
    expect(payer.status).toBe(400);
  });

  it('only parcel-opted-in drivers see and bid on parcel jobs', async () => {
    const customer = await actor(['CUSTOMER']);
    const driver = await actor(['CUSTOMER', 'DRIVER']);
    const created = await book(customer.token, 'idem-parcel-optin-0001').expect(200);
    const rideId = created.body.data.id as string;
    expect(created.body.data.serviceKind).toBe('PARCEL');
    expect(created.body.data.parcel.recipientCode).toMatch(/^\d{4}$/);
    await presenceRepo.upsert(driver.user.id, { online: true, rideEnabled: true, parcelEnabled: false });
    const denied = await http()
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 12000 })
      .expect(409);
    expect(denied.body.errorCode).toBe('DRIVER_OFFLINE');
    const hidden = await http().get('/v1/rides/open?lat=10.7769&lng=106.7009').set('Authorization', `Bearer ${driver.token}`).expect(200);
    expect(hidden.body.data.some((r: { id: string }) => r.id === rideId)).toBe(false);
    await presenceRepo.upsert(driver.user.id, { online: true, parcelEnabled: true });
    const open = await http().get('/v1/rides/open?lat=10.7769&lng=106.7009').set('Authorization', `Bearer ${driver.token}`).expect(200);
    const listed = open.body.data.find((r: { id: string }) => r.id === rideId);
    expect(listed.serviceKind).toBe('PARCEL');
    expect(listed.parcel).toEqual({ sizeClass: 'S', weightKg: 2, note: 'Hộp giày' });
  });

  it('delivers with pickup photo, recipient code and delivery photo; plain start/complete are refused', async () => {
    const customer = await actor(['CUSTOMER']);
    const driver = await actor(['CUSTOMER', 'DRIVER']);
    await presenceRepo.upsert(driver.user.id, { online: true, parcelEnabled: true });
    const { rideId, created } = await assigned(customer, driver, 'idem-parcel-deliver-01');
    const driverView = await http().get(`/v1/parcels/${rideId}`).set('Authorization', `Bearer ${driver.token}`).expect(200);
    expect(driverView.body.data.parcel.recipient.phone).toBe('0907654321');
    expect(driverView.body.data.parcel.recipientCode).toBeUndefined();
    const plain = await http().post(`/v1/rides/${rideId}/start`).set('Authorization', `Bearer ${driver.token}`).send({}).expect(409);
    expect(plain.body.errorCode).toBe('PARCEL_PROOF_REQUIRED');
    const picked = await http()
      .post(`/v1/parcels/${rideId}/pickup`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ photo: PHOTO })
      .expect(200);
    expect(picked.body.data.status).toBe('IN_TRIP');
    expect(picked.body.data.parcel.photos.pickup).toBe(true);
    const wrong = await http()
      .post(`/v1/parcels/${rideId}/deliver`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ photo: PHOTO, recipientCode: '99999' })
      .expect(400);
    expect(wrong.body.errorCode).toBe('PARCEL_CODE_INVALID');
    const done = await http()
      .post(`/v1/parcels/${rideId}/deliver`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ photo: PHOTO, recipientCode: created.body.data.parcel.recipientCode })
      .expect(200);
    expect(done.body.data.status).toBe('COMPLETED');
    expect(done.body.data.parcel.outcome).toBe('DELIVERED');
    const img = await http().get(`/v1/parcels/${rideId}/photos/delivery`).set('Authorization', `Bearer ${customer.token}`).expect(200);
    expect(img.headers['content-type']).toContain('image/png');
    const stranger = await actor(['CUSTOMER']);
    await http().get(`/v1/parcels/${rideId}/photos/delivery`).set('Authorization', `Bearer ${stranger.token}`).expect(404);
  });

  it('fails delivery, returns to sender with a photo', async () => {
    const customer = await actor(['CUSTOMER']);
    const driver = await actor(['CUSTOMER', 'DRIVER']);
    await presenceRepo.upsert(driver.user.id, { online: true, parcelEnabled: true });
    const { rideId } = await assigned(customer, driver, 'idem-parcel-return-01');
    await http().post(`/v1/parcels/${rideId}/pickup`).set('Authorization', `Bearer ${driver.token}`).send({ photo: PHOTO }).expect(200);
    await http().post(`/v1/parcels/${rideId}/returned`).set('Authorization', `Bearer ${driver.token}`).send({ photo: PHOTO }).expect(409);
    const failed = await http()
      .post(`/v1/parcels/${rideId}/fail`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ reason: 'RECIPIENT_UNREACHABLE', note: 'Gọi 3 lần' })
      .expect(200);
    expect(failed.body.data.status).toBe('IN_TRIP');
    expect(failed.body.data.parcel.outcome).toBe('RETURNING');
    const back = await http()
      .post(`/v1/parcels/${rideId}/returned`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ photo: PHOTO })
      .expect(200);
    expect(back.body.data.status).toBe('COMPLETED');
    expect(back.body.data.parcel.outcome).toBe('RETURNED');
    // Booking-time snapshots: service fee in the reference fare, return fee booked on RETURNED.
    expect(back.body.data.parcel.serviceFeeVnd).toBe(1000);
    expect(back.body.data.parcel.returnFeeVnd).toBe(10000);
    expect(await rideRepo.pendingFeeTotal(customer.user.id)).toBe(10000);
  });
});
