import { DriverWorkloadService } from '../../../src/modules/dispatch/driver-workload.service.js';
import { PlatformSettingsService } from '../../../src/platform/settings/platform-settings.service.js';
import { PROD_ENV_OK } from '../../fixtures/prod-env.js';
import { seedVehicleClassOnDriverGrant } from '../../support/driver-class-fixture.js';
import { MemoryRidePickupCodeStore, RIDE_PICKUP_CODE_STORE } from '../../../src/modules/ride/ride-pickup-code.js';
import { MemoryRideParcelStore, RIDE_PARCEL_STORE } from '../../../src/modules/ride/ride-parcel.store.js';
import { INestApplication } from '@nestjs/common';
import { EARNINGS_REPOSITORY, MemoryEarningsRepository } from '../../../src/modules/earnings/index.js';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { createValidationPipe } from '../../../src/platform/http/create-validation-pipe.js';
import { HttpExceptionFilter } from '../../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../../src/platform/http/response.interceptor.js';
import { loadEnv } from '../../../src/platform/config/env.js';
import { AUTH_METHOD_POLICY_REPOSITORY } from '../../../src/modules/identity/auth-method.constants.js';
import { MemoryAuthMethodPolicyRepository } from '../../../src/modules/identity/auth-method.repository.js';
import {
  DRIVER_PRESENCE_REPOSITORY,
  IDENTITY_REPOSITORY,
  SMS_SENDER,
} from '../../../src/modules/identity/identity.constants.js';
import { MemoryDriverPresenceRepository } from '../../../src/modules/identity/driver-presence.repository.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { LEDGER_REPOSITORY } from '../../../src/modules/ledger/ledger.constants.js';
import { MemoryLedgerRepository } from '../../../src/modules/ledger/ledger.repository.js';
import { OPS_FAQ_REPOSITORY } from '../../../src/modules/support/support.constants.js';
import { OPS_NOTIFICATION_REPOSITORY } from '../../../src/modules/communication/notifications/notification.constants.js';
import { PLATFORM_SETTINGS_REPOSITORY } from '../../../src/platform/settings/platform-settings.constants.js';
import { MemoryOpsFaqRepository } from '../../../src/modules/support/ops-faq.repository.js';
import { MemoryOpsNotificationRepository } from '../../../src/modules/communication/notifications/notification.repository.js';
import { negotiationMechanicsSettings } from '../../support/settings-fixture.js';
import {
  MemoryRideCustomerRatingStore,
  RIDE_CUSTOMER_RATING_STORE,
} from '../../../src/modules/ride/ride-customer-rating.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import { MemoryPartnerRepository } from '../../../src/modules/partner/partner.repository.js';
import { CHECKOUT_REPOSITORY, PAYMENT_REPOSITORY } from '../../../src/modules/payment/payment.constants.js';
import { MemoryCheckoutRepository } from '../../../src/modules/payment/checkout/checkout.repository.js';
import { MemoryPaymentRepository } from '../../../src/modules/payment/payment.repository.js';
import { haversineKm, quoteReferenceFareVnd } from '../../../src/modules/ride/ride-geo.js';
import { roundUpToFareStep } from '../../../src/modules/ride-vehicle/ride-vehicle-class.js';
import { RIDE_CLOCK, RIDE_REPOSITORY, type RideClock } from '../../../src/modules/ride/ride.constants.js';
import { RideModule } from '../../../src/modules/ride/ride.module.js';
import { PROMOTION_REPOSITORY } from '../../../src/modules/promotion/promotion.constants.js';
import { MemoryPromotionRepository } from '../../../src/modules/promotion/promotion.repository.js';
import { MemoryRideRepository } from '../../../src/modules/ride/ride.repository.js';
import { RIDE_VEHICLE_CLASS_REPOSITORY, RIDE_ZONE_TARIFF_REPOSITORY } from '../../../src/modules/ride-vehicle/ride-vehicle-class.constants.js';
import { MemoryRideZoneTariffRepository } from '../../../src/modules/ride-vehicle/ride-zone-tariff.repository.js';
import { MemoryRideVehicleClassRepository } from '../../../src/modules/ride-vehicle/ride-vehicle-class.repository.js';
import {
  EMAIL_SUPPRESSION_REPOSITORY,
  MemoryEmailSuppressionRepository,
} from '../../../src/integrations/email/email-suppression.repository.js';
import { INTEGRATION_SETTINGS_REPOSITORY } from '../../../src/platform/integration-settings/integration-settings.constants.js';
import { MemoryIntegrationSettingsRepository } from '../../../src/platform/integration-settings/integration-settings.repository.js';
import { MemoryPublicPagesRepository } from '../../../src/modules/public-pages/public-pages.repository.js';
import { PUBLIC_PAGES_REPOSITORY } from '../../../src/modules/public-pages/public-pages.types.js';
import { RideVehicleClassService } from '../../../src/modules/ride-vehicle/ride-vehicle-class.service.js';

const OPS_EMAIL = 'ops@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';
const CLOCK_START = new Date('2026-10-13T12:00:00.000Z');

const pickup = { lat: 10.776889, lng: 106.700806, label: 'District 1' };
const dropoff = { lat: 10.823099, lng: 106.629664, label: 'Airport' };

class ManualClock implements RideClock {
  constructor(private current: Date) {}

  now(): Date {
    return this.current;
  }

  set(next: Date): void {
    this.current = next;
  }

  advanceSeconds(seconds: number): void {
    this.current = new Date(this.current.getTime() + seconds * 1000);
  }
}

describe('ride negotiation http', () => {
  let app: INestApplication;
  let repository: MemoryIdentityRepository;
  let partners: MemoryPartnerRepository;
  let sms: MockSmsSender;
  let clock: ManualClock;
  let phoneSerial = 100;

  beforeAll(async () => {
    repository = new MemoryIdentityRepository();
    partners = new MemoryPartnerRepository();
    sms = new MockSmsSender('test');
    clock = new ManualClock(CLOCK_START);

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
              RIDE_OFFER_TTL_SECONDS: '60',
              RIDE_MIN_FARE_VND: '10000',
              RIDE_MAX_FARE_VND: '500000',
              RIDE_REFERENCE_VND_PER_KM: '8000',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
              PARTNER_ELIGIBILITY_BYPASS: 'true',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        RideModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(await negotiationMechanicsSettings())
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(repository)
      .overrideProvider(RIDE_CLOCK)
      .useValue(clock)
      .overrideProvider(PARTNER_REPOSITORY)
      .useValue(partners)
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    seedVehicleClassOnDriverGrant(app, repository);
    await app.get(OpsAuthService).ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');
  });

  afterAll(async () => {
    await app.close();
  });

  afterEach(() => {
    clock.set(CLOCK_START);
  });

  it('returns the original ride for the same idempotency key and rejects a second open ride', async () => {
    const customer = await login();
    const first = await postRide(customer.token, 'idem-create-ride-1', 30_000);
    expect(first.status).toBe(200);
    expect(first.body.data.offers).toEqual([]);
    expect(first.body.data.status).toBe('NEGOTIATING');
    expect(first.body.data.offeredFareVnd).toBe(30_000);
    expect(first.body.data.referenceFareVnd).toBe(
      roundUpToFareStep(quoteReferenceFareVnd(haversineKm(pickup, dropoff), 5000, 10_000)),
    );
    expect(Number.isInteger(first.body.data.referenceFareVnd)).toBe(true);

    const profile = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(profile.body.data.grants).toEqual([{ role: 'CUSTOMER', status: 'ACTIVE' }]);

    const replay = await postRide(customer.token, 'idem-create-ride-1', 40_000);
    expect(replay.status).toBe(200);
    expect(replay.body.data.id).toBe(first.body.data.id);
    expect(replay.body.data.offeredFareVnd).toBe(30_000);

    const second = await postRide(customer.token, 'idem-create-ride-2', 30_000);
    expect(second.status).toBe(409);
    expect(second.body.errorCode).toBe('RIDE_ALREADY_OPEN');
  });

  it('quotes distance and the reference fare that create() stores', async () => {
    const customer = await login();
    const quote = await request(app.getHttpServer())
      .post('/v1/rides/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ pickup, dropoff })
      .expect(200);
    const km = haversineKm(pickup, dropoff);
    const referenceFareVnd = roundUpToFareStep(quoteReferenceFareVnd(km, 5000, 10_000));
    expect(referenceFareVnd % 1000).toBe(0);
    expect(quote.body.data).toMatchObject({
      distanceKm: Math.round(km * 10) / 10,
      referenceFareVnd,
      minFareVnd: 10_000,
    });
    expect(quote.body.data.maxFareVnd).toEqual(expect.any(Number));
    expect(quote.body.data.route).toEqual({
      available: false,
      provider: 'none',
      coords: [],
      distanceM: null,
      durationSec: null,
    });
    expect(quote.body.data.options).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: 'MOTORBIKE', referenceFareVnd }),
      ]),
    );
    await request(app.getHttpServer())
      .post('/v1/rides/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ pickup })
      .expect(400);
  });

  it('returns unavailable road geometry on GET /v1/rides/route when ROUTING_PROVIDER=none', async () => {
    const customer = await login();
    const res = await request(app.getHttpServer())
      .get('/v1/rides/route')
      .query({
        fromLat: pickup.lat,
        fromLng: pickup.lng,
        toLat: dropoff.lat,
        toLng: dropoff.lng,
      })
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(res.body.data).toEqual({
      available: false,
      provider: 'none',
      coords: [],
      distanceM: null,
      durationSec: null,
    });
  });

  it('assigns the countered driver and agreed fare, and replays the same selection key', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');

    const created = await postRide(customer.token, 'idem-counter-create', 30_000);
    expect(created.status).toBe(200);
    const rideId = created.body.data.id as string;

    const offer = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 45_000 })
      .expect(200);
    expect(offer.body.data.offers).toEqual([
      expect.objectContaining({
        driverId: driver.userId,
        amountVnd: 45_000,
        kind: 'COUNTER',
        status: 'PENDING',
      }),
    ]);

    const offerId = offer.body.data.offers[0].id as string;
    const selected = await selectRide(customer.token, rideId, offerId, 'idem-counter-select');
    expect(selected.status).toBe(200);
    expect(selected.body.data.status).toBe('ASSIGNED');
    expect(selected.body.data.assignedDriverId).toBe(driver.userId);
    expect(selected.body.data.agreedFareVnd).toBe(45_000);
    expect(selected.body.data.selectedOfferId).toBe(offerId);
    expect(selected.body.data.offers[0].status).toBe('SELECTED');

    const replay = await selectRide(customer.token, rideId, offerId, 'idem-counter-select');
    expect(replay.status).toBe(200);
    expect(replay.body.data).toEqual(selected.body.data);
  });

  it('lets only one of two racing selections assign a driver', async () => {
    const customer = await login();
    const driverA = await login();
    const driverB = await login();
    await repository.insertGrant(driverA.userId, 'DRIVER', 'ACTIVE');
    await repository.insertGrant(driverB.userId, 'DRIVER', 'ACTIVE');

    const created = await postRide(customer.token, 'idem-race-create', 30_000);
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
      selectRide(customer.token, rideId, offerAId, 'idem-race-select-a'),
      selectRide(customer.token, rideId, offerBId, 'idem-race-select-b'),
    ]);
    const responses = [first, second];
    expect(responses.map((response) => response.status).sort((a, b) => a - b)).toEqual([200, 409]);
    const failure = responses.find((response) => response.status === 409);
    const success = responses.find((response) => response.status === 200);
    expect(failure?.body.errorCode).toBe('RIDE_OFFER_UNAVAILABLE');
    expect(success?.body.data.status).toBe('ASSIGNED');

    const assignedDriverId = success?.body.data.assignedDriverId as string;
    const agreedFareVnd = assignedDriverId === driverA.userId ? 40_000 : 42_000;
    expect(success?.body.data.agreedFareVnd).toBe(agreedFareVnd);
    expect(success?.body.data.offers.map((item: { status: string }) => item.status).sort()).toEqual([
      'LOST',
      'SELECTED',
    ]);

    const stored = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(stored.body.data.assignedDriverId).toBe(assignedDriverId);
    expect(stored.body.data.status).toBe('ASSIGNED');
  });

  it('t71u: offer TTL race — accept just before expiry wins, after expiry is 409 and the driver may re-offer', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = (await postRide(customer.token, 'idem-t71u-race', 30_000)).body.data.id as string;
    const first = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 35_000 })
      .expect(200);
    const offerId = first.body.data.offers[0].id as string;
    const ttlMs = Date.parse(first.body.data.offers[0].expiresAt) - clock.now().getTime();
    clock.advanceSeconds(Math.ceil(ttlMs / 1000) + 1);
    const late = await selectRide(customer.token, rideId, offerId, 'idem-t71u-late');
    expect(late.status).toBe(409);
    expect(late.body.errorCode).toBe('RIDE_OFFER_EXPIRED');
    // Driver re-offers on the still-open ride; selecting inside the fresh TTL succeeds.
    const again = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 35_000 })
      .expect(200);
    const fresh = again.body.data.offers[0];
    expect(fresh.status).toBe('PENDING');
    expect(Date.parse(fresh.expiresAt)).toBeGreaterThan(clock.now().getTime());
    clock.advanceSeconds(Math.max(0, Math.floor(ttlMs / 1000) - 1));
    const ok = await selectRide(customer.token, rideId, fresh.id as string, 'idem-t71u-ok');
    expect(ok.status).toBe(200);
  });

  it('t71u: a driver on an active job cannot bid and sees no open requests', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = (await postRide(customer.token, 'idem-t71u-busy', 30_000)).body.data.id as string;
    const workload = app.get(DriverWorkloadService);
    workload.useSource({
      activeJobCounts: async (ids) => new Map(ids.map((id) => [id, id === driver.userId ? 1 : 0])),
    });
    try {
      const bid = await request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/offers`)
        .set('Authorization', `Bearer ${driver.token}`)
        .send({ amountVnd: 35_000 });
      expect(bid.status).toBe(409);
      expect(bid.body.errorCode).toBe('DRIVER_AT_CAPACITY');
    } finally {
      workload.useSource(null);
    }
    await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 35_000 })
      .expect(200);
  });

  it('rejects selection of an expired offer', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const created = await postRide(customer.token, 'idem-expire-create', 30_000);
    const rideId = created.body.data.id as string;
    const offer = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 35_000 })
      .expect(200);
    const offerId = offer.body.data.offers[0].id as string;

    clock.advanceSeconds(61);
    const expired = await selectRide(customer.token, rideId, offerId, 'idem-expire-select');
    expect(expired.status).toBe(409);
    expect(expired.body.errorCode).toBe('RIDE_OFFER_EXPIRED');

    // The request window (RIDE_REQUEST_WINDOW_SECONDS = 300) outlives one offer's
    // TTL, so the ride keeps collecting bids until the window closes.
    const stillOpen = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(stillOpen.body.data.status).toBe('NEGOTIATING');

    clock.advanceSeconds(300);
    const stored = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(stored.body.data.status).toBe('EXPIRED');
    expect(stored.body.data.assignedDriverId).toBeNull();
  });

  it('rejects an offer on the customer’s own ride', async () => {
    const user = await login();
    await repository.insertGrant(user.userId, 'DRIVER', 'ACTIVE');
    const created = await postRide(user.token, 'idem-self-offer', 30_000);
    const rideId = created.body.data.id as string;

    const denied = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${user.token}`)
      .send({ amountVnd: 35_000 })
      .expect(403);
    expect(denied.body.errorCode).toBe('RIDE_SELF_OFFER');
  });

  it('hides a ride from another customer', async () => {
    const owner = await login();
    const other = await login();
    const created = await postRide(owner.token, 'idem-private-ride', 30_000);
    const rideId = created.body.data.id as string;

    const hidden = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${other.token}`)
      .expect(404);
    expect(hidden.body.errorCode).toBe('RIDE_NOT_FOUND');
  });

  it('rejects a fare above the TEST_ONLY maximum', async () => {
    const customer = await login();
    // 500_001 is within one fare step of the 500_000 cap and is clamped to it
    // (stepFareWithinCap); a full step above the cap is rejected.
    const response = await postRide(customer.token, 'idem-fare-too-high', 501_000);
    expect(response.status).toBe(400);
    expect(response.body.errorCode).toBe('RIDE_FARE_OUT_OF_RANGE');
  });

  it('does not upgrade a suspended customer grant', async () => {
    const customer = await login();
    const customerGrant = (await repository.listGrants(customer.userId)).find(
      (grant) => grant.role === 'CUSTOMER',
    );
    await repository.updateGrantStatus(customerGrant!.id, 'SUSPENDED');

    const denied = await postRide(customer.token, 'idem-suspended-customer', 30_000);
    expect(denied.status).toBe(403);
    expect(denied.body.errorCode).toBe('ROLE_NOT_ACTIVE');
  });

  it('lists a negotiating ride to an active driver without a phone field', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');

    const created = await postRide(customer.token, 'idem-open-list', 30_000);
    expect(created.status).toBe(200);
    await goOnlineNearPickup(driver.token);

    const listed = await request(app.getHttpServer())
      .get('/v1/rides/open')
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    const match = (listed.body.data as { id: string }[]).find((ride) => ride.id === created.body.data.id);
    expect(match).toEqual({
      id: created.body.data.id,
      status: 'NEGOTIATING',
      pickup,
      dropoff,
      offeredFareVnd: 30_000,
      referenceFareVnd: created.body.data.referenceFareVnd,
      vehicleClassCode: 'MOTORBIKE',
      imageUrl: null,
      expiresAt: created.body.data.expiresAt,
      offerCount: 0,
      customerRating: { average: null, count: 0 },
      pickupDistanceKm: expect.any(Number),
      tripDistanceKm: expect.toBeOneOf([null, expect.any(Number)]),
      intercity: false,
      stops: [],
      routeVersion: 0,
      maxCounterVnd: expect.any(Number),
      counterHeadroomPercent: expect.any(Number),
      serviceKind: 'RIDE',
      parcel: null,
    });
    expect(JSON.stringify(listed.body.data)).not.toContain('"phone"');
    expect(JSON.stringify(listed.body.data)).not.toContain(customer.userId);
  });

  it('rejects a customer without a driver grant from the open ride list', async () => {
    const customer = await login();
    const created = await postRide(customer.token, 'idem-open-list-denied', 30_000);
    expect(created.status).toBe(200);

    const denied = await request(app.getHttpServer())
      .get('/v1/rides/open')
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(403);
    expect(denied.body.errorCode).toBe('ROLE_NOT_ACTIVE');
  });

  it('requires an active driver grant to offer', async () => {
    const customer = await login();
    const driver = await login();
    const created = await postRide(customer.token, 'idem-driver-grant', 30_000);
    const rideId = created.body.data.id as string;

    const denied = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 35_000 })
      .expect(403);
    expect(denied.body.errorCode).toBe('ROLE_NOT_ACTIVE');
  });

  it('rejects an operator token', async () => {
    const ops = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);

    const denied = await postRide(ops.body.data.accessToken as string, 'idem-ops-denied', 30_000);
    expect(denied.status).toBe(403);
  });

  it('online-paid ride completes without a cash obligation and credits the driver', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = await assignRide(customer, driver, 'idem-online-create', 'idem-online-select');
    const checkout = app.get<MemoryCheckoutRepository>(CHECKOUT_REPOSITORY, { strict: false });
    const ledgerRepo = app.get<MemoryLedgerRepository>(LEDGER_REPOSITORY, { strict: false });
    await checkout.setSelection('RIDE', rideId, 'MOMO');
    const intent = await checkout.upsertAttempt({
      entityType: 'RIDE', entityId: rideId, method: 'MOMO', methodCode: 'MOMO', provider: 'momo',
      amountVnd: 40_000, providerRef: 'DGRTEST0000000000', paymentUrl: null, deeplink: null,
    });
    await checkout.update(intent.id, { status: 'CAPTURED', providerTransId: '1' });

    const before = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}/collection`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(before.body.data).toMatchObject({ methodCode: 'MOMO', status: 'PAID', paidOnlineVnd: 40_000, cashToCollectVnd: 0 });
    await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}/collection`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(404);

    for (const step of ['en-route', 'arrived']) {
      await request(app.getHttpServer()).post(`/v1/rides/${rideId}/${step}`).set('Authorization', `Bearer ${driver.token}`).expect(200);
    }
    const code = await pickupCodeFor(customer, rideId);
    await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/start`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ pickupCode: code })
      .expect(200);
    await request(app.getHttpServer()).post(`/v1/rides/${rideId}/complete`).set('Authorization', `Bearer ${driver.token}`).expect(200);

    expect(await ledgerRepo.findByEntity('RIDE', rideId, 'COD_OBLIGATION_POSTED')).toBeNull();
    expect((await ledgerRepo.findByEntity('RIDE', rideId, 'PSP_PREPAID_APPLIED'))?.amountVnd).toBe(40_000);
    expect((await checkout.findById(intent.id))?.settledAt).toBeInstanceOf(Date);
  });

  it('runs assigned → en-route → arrived → in-trip → completed and keeps agreedFareVnd', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = await assignRide(customer, driver, 'idem-lifecycle-create', 'idem-lifecycle-select');

    const enRoute = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/en-route`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(enRoute.body.data.status).toBe('DRIVER_EN_ROUTE');
    expect(enRoute.body.data.agreedFareVnd).toBe(40_000);
    expect(typeof enRoute.body.requestId).toBe('string');

    const arrived = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/arrived`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(arrived.body.data.status).toBe('DRIVER_ARRIVED');

    const lifecycleCode = await pickupCodeFor(customer, rideId);
    const started = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/start`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ pickupCode: lifecycleCode })
      .expect(200);
    expect(started.body.data.status).toBe('IN_TRIP');

    const completed = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/complete`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(completed.body.data.status).toBe('COMPLETED');
    expect(completed.body.data.agreedFareVnd).toBe(40_000);

    const journal = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}/ledger`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(journal.body.data.event).toBe('COD_OBLIGATION_POSTED');
    expect(journal.body.data.amountVnd).toBe(40_000);
    expect(journal.body.data.status).toBe('POSTED');
    const debit = journal.body.data.entries
      .filter((entry: { direction: string }) => entry.direction === 'DEBIT')
      .reduce((sum: number, entry: { amountVnd: number }) => sum + entry.amountVnd, 0);
    const credit = journal.body.data.entries
      .filter((entry: { direction: string }) => entry.direction === 'CREDIT')
      .reduce((sum: number, entry: { amountVnd: number }) => sum + entry.amountVnd, 0);
    expect(debit).toBe(credit);

    const ops = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    const opsList = await request(app.getHttpServer())
      .get('/v1/ops/rides?page=1&limit=10')
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(opsList.body.data.page).toBe(1);
    expect(opsList.body.data.limit).toBe(10);
    expect(opsList.body.data.total).toBeGreaterThanOrEqual(1);
    // Other tests' rides share the frozen clock, so this one is not always on page 1: walk the pages.
    let listed = false;
    const pages = Math.ceil(opsList.body.data.total / 10);
    for (let page = 1; page <= pages && !listed; page += 1) {
      const res = await request(app.getHttpServer())
        .get(`/v1/ops/rides?page=${page}&limit=10`)
        .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
        .expect(200);
      listed = res.body.data.items.some((ride: { id: string }) => ride.id === rideId);
    }
    expect(listed).toBe(true);

    const filteredByStatus = await request(app.getHttpServer())
      .get('/v1/ops/rides?page=1&limit=10&status=NEGOTIATING')
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(
      filteredByStatus.body.data.items.every(
        (r: { status: string }) => r.status === 'NEGOTIATING',
      ),
    ).toBe(true);

    const filteredByQ = await request(app.getHttpServer())
      .get(`/v1/ops/rides?page=1&limit=10&q=${rideId.slice(0, 8)}`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(
      filteredByQ.body.data.items.some((r: { id: string }) => r.id === rideId),
    ).toBe(true);

    const opsDetail = await request(app.getHttpServer())
      .get(`/v1/ops/rides/${rideId}`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(opsDetail.body.data.id).toBe(rideId);
    // Admin resolves the booking customer's name from this id (ops-only field).
    expect(opsDetail.body.data.customerId).toBe(customer.userId);

    const opsLedger = await request(app.getHttpServer())
      .get(`/v1/ops/rides/${rideId}/ledger`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(opsLedger.body.data.id).toBe(journal.body.data.id);
  });

  it('shows the assigned driver’s fresh location to the ride customer only (DEC-PROD-031)', async () => {
    const customer = await login();
    const driver = await login();
    const stranger = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = await assignRide(customer, driver, 'idem-loc-create', 'idem-loc-select');
    const locationOf = (token: string) =>
      request(app.getHttpServer())
        .get(`/v1/rides/${rideId}/driver-location`)
        .set('Authorization', `Bearer ${token}`);

    // Nothing reported yet.
    expect((await locationOf(customer.token).expect(200)).body.data).toEqual({ location: null });

    // Only an active driver may report; bad coordinates are rejected.
    await request(app.getHttpServer())
      .post('/v1/me/presence/location')
      .set('Authorization', `Bearer ${stranger.token}`)
      .send({ lat: 10.78, lng: 106.7 })
      .expect(403);
    await request(app.getHttpServer())
      .post('/v1/me/presence/location')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ lat: 91, lng: 106.7 })
      .expect(400);
    const reported = await request(app.getHttpServer())
      .post('/v1/me/presence/location')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ lat: 10.78, lng: 106.7 })
      .expect(200);
    expect(reported.body.data).toMatchObject({ lat: 10.78, lng: 106.7 });

    clock.set(new Date());
    const seen = await locationOf(customer.token).expect(200);
    expect(seen.body.data.location).toMatchObject({ lat: 10.78, lng: 106.7 });
    expect(typeof seen.body.data.location.at).toBe('string');

    // The heartbeat keeps the driver's online/service choices.
    const presence = await request(app.getHttpServer())
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ online: true })
      .expect(200);
    expect(presence.body.data).toMatchObject({ online: true, lat: 10.78, lng: 106.7 });

    // Other users (including the driver) get 404, like GET /rides/:id for strangers.
    await locationOf(stranger.token).expect(404);
    await locationOf(driver.token).expect(404);

    // Older than 2 minutes → hidden.
    clock.set(new Date(Date.now() + 3 * 60_000));
    expect((await locationOf(customer.token).expect(200)).body.data).toEqual({ location: null });

    // After the ride ends the position is no longer shared.
    clock.set(new Date());
    await request(app.getHttpServer())
      .post(`/v1/me/presence/location`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ lat: 10.79, lng: 106.71 })
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/cancel`)
      .set('Authorization', `Bearer ${customer.token}`)
      .send({})
      .expect(200);
    expect((await locationOf(customer.token).expect(200)).body.data).toEqual({ location: null });
  });

  it('forbids a non-assigned driver from starting a trip', async () => {
    const customer = await login();
    const driver = await login();
    const other = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    await repository.insertGrant(other.userId, 'DRIVER', 'ACTIVE');
    const rideId = await assignRide(customer, driver, 'idem-wrong-driver-create', 'idem-wrong-driver-select');

    await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/en-route`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/arrived`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);

    const denied = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/start`)
      .set('Authorization', `Bearer ${other.token}`)
      .send({ pickupCode: '0000' });
    expect(denied.status).toBe(403);
    expect(denied.body.errorCode).toBe('RIDE_NOT_ASSIGNED_DRIVER');
  });

  it('issues the pickup code to the customer only and makes the driver submit it', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = await assignRide(customer, driver, 'idem-code-create', 'idem-code-select');
    const code = await pickupCodeFor(customer, rideId);
    expect(await pickupCodeFor(customer, rideId)).toBe(code);

    const driverView = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(driverView.body.data.pickupCode).toBeUndefined();

    for (const step of ['en-route', 'arrived']) {
      const res = await request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/${step}`)
        .set('Authorization', `Bearer ${driver.token}`)
        .expect(200);
      expect(res.body.data.pickupCode).toBeUndefined();
    }

    const missing = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/start`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({});
    expect(missing.status).toBe(422);
    expect(missing.body.errorCode).toBe('RIDE_PICKUP_CODE_REQUIRED');

    const wrongCode = code === '0000' ? '1111' : '0000';
    const wrong = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/start`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ pickupCode: wrongCode });
    expect(wrong.status).toBe(422);
    expect(wrong.body.errorCode).toBe('RIDE_PICKUP_CODE_INVALID');

    const started = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/start`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ pickupCode: code })
      .expect(200);
    expect(started.body.data.status).toBe('IN_TRIP');
    expect(started.body.data.pickupCode).toBeUndefined();

    const afterStart = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(afterStart.body.data.pickupCode).toBeUndefined();
  });

  it('starts without a code and shows none when RIDE_PICKUP_CODE_REQUIRED is off', async () => {
    const settings = app.get(PlatformSettingsService);
    await settings.patch('RIDE_PICKUP_CODE_REQUIRED', 'false', 'test off', 'ops-test');
    try {
      const customer = await login();
      const driver = await login();
      await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
      const rideId = await assignRide(customer, driver, 'idem-nocode-create', 'idem-nocode-select');
      const customerView = await request(app.getHttpServer())
        .get(`/v1/rides/${rideId}`)
        .set('Authorization', `Bearer ${customer.token}`)
        .expect(200);
      expect(customerView.body.data.pickupCode).toBeUndefined();
      for (const step of ['en-route', 'arrived']) {
        await request(app.getHttpServer())
          .post(`/v1/rides/${rideId}/${step}`)
          .set('Authorization', `Bearer ${driver.token}`)
          .expect(200);
      }
      const started = await request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/start`)
        .set('Authorization', `Bearer ${driver.token}`)
        .send({})
        .expect(200);
      expect(started.body.data.status).toBe('IN_TRIP');
    } finally {
      await settings.patch('RIDE_PICKUP_CODE_REQUIRED', 'true', 'test on', 'ops-test');
    }
  });

  it('locks the pickup code after the configured number of wrong attempts', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = await assignRide(customer, driver, 'idem-lock-create', 'idem-lock-select');
    const code = await pickupCodeFor(customer, rideId);
    for (const step of ['en-route', 'arrived']) {
      await request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/${step}`)
        .set('Authorization', `Bearer ${driver.token}`)
        .expect(200);
    }
    const wrongCode = code === '0000' ? '1111' : '0000';
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const res = await request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/start`)
        .set('Authorization', `Bearer ${driver.token}`)
        .send({ pickupCode: wrongCode });
      expect(res.body.errorCode).toBe('RIDE_PICKUP_CODE_INVALID');
    }
    const locked = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/start`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ pickupCode: code });
    expect(locked.status).toBe(423);
    expect(locked.body.errorCode).toBe('RIDE_PICKUP_CODE_LOCKED');
  });

  it('rejects an illegal ride status transition with 409', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = await assignRide(customer, driver, 'idem-illegal-create', 'idem-illegal-select');

    const skipped = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/arrived`)
      .set('Authorization', `Bearer ${driver.token}`);
    expect(skipped.status).toBe(409);
    expect(skipped.body.errorCode).toBe('RIDE_STATUS_CONFLICT');
  });

  it('allows customer cancel before IN_TRIP and blocks after start', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = await assignRide(customer, driver, 'idem-cancel-pre-create', 'idem-cancel-pre-select');

    const cancelled = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/cancel`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(cancelled.body.data.status).toBe('CANCELLED');
    expect(cancelled.body.data.cancelledBy).toBe('CUSTOMER');

    const againCustomer = await login();
    const againDriver = await login();
    await repository.insertGrant(againDriver.userId, 'DRIVER', 'ACTIVE');
    const tripId = await assignRide(
      againCustomer,
      againDriver,
      'idem-cancel-post-create',
      'idem-cancel-post-select',
    );
    await request(app.getHttpServer())
      .post(`/v1/rides/${tripId}/en-route`)
      .set('Authorization', `Bearer ${againDriver.token}`)
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/rides/${tripId}/arrived`)
      .set('Authorization', `Bearer ${againDriver.token}`)
      .expect(200);
    const tripCode = await pickupCodeFor(againCustomer, tripId);
    await request(app.getHttpServer())
      .post(`/v1/rides/${tripId}/start`)
      .set('Authorization', `Bearer ${againDriver.token}`)
      .send({ pickupCode: tripCode })
      .expect(200);

    const blocked = await request(app.getHttpServer())
      .post(`/v1/rides/${tripId}/cancel`)
      .set('Authorization', `Bearer ${againCustomer.token}`);
    expect(blocked.status).toBe(409);
    expect(blocked.body.errorCode).toBe('RIDE_NOT_CANCELLABLE');
  });

  it('lists customer ride history and supports ops cancel + TEST_ONLY reassign', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const rideId = await assignRide(customer, driver, 'idem-hist-create', 'idem-hist-select');

    const history = await request(app.getHttpServer())
      .get('/v1/rides?page=1&limit=10')
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(history.body.data.items.some((ride: { id: string }) => ride.id === rideId)).toBe(true);

    const ops = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);

    const reassigned = await request(app.getHttpServer())
      .post(`/v1/ops/rides/${rideId}/reassign`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .send({ reason: 'TEST_ONLY clear assignment for dispatch retry' })
      .expect(200);
    expect(reassigned.body.data.status).toBe('NEGOTIATING');
    expect(reassigned.body.data.assignedDriverId).toBeNull();

    const cancelled = await request(app.getHttpServer())
      .post(`/v1/ops/rides/${rideId}/cancel`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .send({ reason: 'Customer unreachable after ops review' })
      .expect(200);
    expect(cancelled.body.data.status).toBe('CANCELLED');
    expect(cancelled.body.data.cancelledBy).toBe('OPS');
  });

  it('hides open rides when driver presence is offline', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    await postRide(customer.token, 'idem-presence-open', 30_000).expect(200);

    await request(app.getHttpServer())
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ online: false })
      .expect(200);

    const offline = await request(app.getHttpServer())
      .get('/v1/rides/open')
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(offline.body.data).toEqual([]);

    await request(app.getHttpServer())
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ online: true, lat: 10.77, lng: 106.7 })
      .expect(200);

    const online = await request(app.getHttpServer())
      .get('/v1/rides/open')
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(online.body.data.length).toBeGreaterThanOrEqual(1);
  });

  it('hides open rides while the driver has ride requests switched off (DEC-PROD-023)', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    await postRide(customer.token, 'idem-presence-toggle', 30_000).expect(200);
    const presence = (body: Record<string, unknown>) =>
      request(app.getHttpServer())
        .post('/v1/me/presence')
        .set('Authorization', `Bearer ${driver.token}`)
        .send(body)
        .expect(200);
    const open = () =>
      request(app.getHttpServer())
        .get('/v1/rides/open')
        .set('Authorization', `Bearer ${driver.token}`)
        .expect(200);

    const off = await presence({ online: true, rideEnabled: false, foodEnabled: true, lat: 10.77, lng: 106.7 });
    expect(off.body.data).toMatchObject({ online: true, rideEnabled: false, foodEnabled: true });
    expect((await open()).body.data).toEqual([]);

    // Going online again without the toggles keeps the stored choice.
    const kept = await presence({ online: true });
    expect(kept.body.data.rideEnabled).toBe(false);
    expect((await open()).body.data).toEqual([]);

    await presence({ online: true, rideEnabled: true });
    expect((await open()).body.data.length).toBeGreaterThanOrEqual(1);
    const read = await request(app.getHttpServer())
      .get('/v1/me/presence')
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(read.body.data).toMatchObject({ rideEnabled: true, foodEnabled: true });
    await request(app.getHttpServer())
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ online: true, rideEnabled: 'no' })
      .expect(400);
  });

  async function pickupCodeFor(customer: { token: string }, rideId: string): Promise<string> {
    const res = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    const code = res.body.data.pickupCode as string;
    expect(code).toMatch(/^\d{4}$/);
    return code;
  }

  it('re-checks the offering driver at selection (RIDE-002)', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const created = await postRide(customer.token, 'idem-ride002-create', 30_000).expect(200);
    const rideId = created.body.data.id as string;
    const offer = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 40_000 })
      .expect(200);
    const offerId = offer.body.data.offers[0].id as string;
    await request(app.getHttpServer())
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ online: false })
      .expect(200);
    const refused = await selectRide(customer.token, rideId, offerId, 'idem-ride002-select-1');
    expect(refused.status).toBe(409);
    expect(refused.body.errorCode).toBe('RIDE_OFFER_DRIVER_UNAVAILABLE');
    await goOnlineNearPickup(driver.token);
    const ok = await selectRide(customer.token, rideId, offerId, 'idem-ride002-select-2');
    expect(ok.status).toBe(200);
  });

  it('refuses an offer from a driver far from the pickup (RIDE-001)', async () => {
    const customer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const created = await postRide(customer.token, 'idem-ride001-create', 30_000).expect(200);
    await request(app.getHttpServer())
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ online: true, lat: pickup.lat + 2, lng: pickup.lng })
      .expect(200);
    const far = await request(app.getHttpServer())
      .post(`/v1/rides/${created.body.data.id}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 40_000 });
    expect(far.status).toBe(409);
    expect(far.body.errorCode).toBe('DRIVER_TOO_FAR');
  });

  async function assignRide(
    customer: { token: string; userId: string },
    driver: { token: string; userId: string },
    createKey: string,
    selectKey: string,
  ): Promise<string> {
    const created = await postRide(customer.token, createKey, 30_000);
    expect(created.status).toBe(200);
    const rideId = created.body.data.id as string;
    const offer = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 40_000 })
      .expect(200);
    const offerId = offer.body.data.offers[0].id as string;
    const selected = await selectRide(customer.token, rideId, offerId, selectKey);
    expect(selected.status).toBe(200);
    expect(selected.body.data.status).toBe('ASSIGNED');
    return rideId;
  }

  async function login(): Promise<{ token: string; userId: string }> {
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

  // --- RIDE-CAR (DG-DEC-VEH-001 Wave 1) ---
  it('RIDE-CAR: rejects create when vehicleClassCode is missing (no silent MOTORBIKE)', async () => {
    const customer = await login();
    const denied = await request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'idem-ride-car-missing-class')
      .send({ pickup, dropoff, offeredFareVnd: 30_000 });
    expect(denied.status).toBe(400);
  });

  it('RIDE-CAR: stores CAR_4 when requested and quotes include Car options', async () => {
    const customer = await login();
    const quote = await request(app.getHttpServer())
      .post('/v1/rides/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ pickup, dropoff })
      .expect(200);
    const codes = (quote.body.data.options as { code: string }[]).map((o) => o.code);
    expect(codes).toEqual(expect.arrayContaining(['MOTORBIKE', 'CAR_4', 'CAR_7']));

    const created = await postRide(customer.token, 'idem-ride-car-create-car4', 30_000, 'CAR_4');
    expect(created.status).toBe(200);
    expect(created.body.data.vehicleClassCode).toBe('CAR_4');
  });

  it('RIDE-CAR: motorbike driver cannot offer on a CAR_4 ride (class mismatch)', async () => {
    const customer = await login();
    const bikeDriver = await login();
    await repository.insertGrant(bikeDriver.userId, 'DRIVER', 'ACTIVE');
    // No partner metadata → eligibility defaults legacy MOTORBIKE

    const created = await postRide(customer.token, 'idem-ride-car-mismatch', 30_000, 'CAR_4');
    expect(created.status).toBe(200);
    const rideId = created.body.data.id as string;

    const denied = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${bikeDriver.token}`)
      .send({ amountVnd: 35_000 })
      .expect(403);
    expect(denied.body.errorCode).toBe('RIDE_VEHICLE_CLASS_MISMATCH');
  });

  it('RIDE-CAR: CAR_4 driver can offer on a matching CAR_4 ride', async () => {
    const customer = await login();
    const carDriver = await login();
    await repository.insertGrant(carDriver.userId, 'DRIVER', 'ACTIVE');
    await partners.upsertSubmit({
      id: `app-car4-${carDriver.userId}`,
      userId: carDriver.userId,
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'CAR_4' },
      documents: [],
      now: clock.now(),
    });

    const created = await postRide(customer.token, 'idem-ride-car-match', 30_000, 'CAR_4');
    expect(created.status).toBe(200);
    const rideId = created.body.data.id as string;

    const offer = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${carDriver.token}`)
      .send({ amountVnd: 35_000 })
      .expect(200);
    expect(offer.body.data.offers).toEqual([
      expect.objectContaining({
        driverId: carDriver.userId,
        amountVnd: 35_000,
        status: 'PENDING',
      }),
    ]);
  });

  it('RIDE-CAR: open list for CAR_4 driver only shows CAR_4 rides', async () => {
    const customerBike = await login();
    const customerCar = await login();
    const carDriver = await login();
    await repository.insertGrant(carDriver.userId, 'DRIVER', 'ACTIVE');
    await partners.upsertSubmit({
      id: `app-car4-open-${carDriver.userId}`,
      userId: carDriver.userId,
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'CAR_4' },
      documents: [],
      now: clock.now(),
    });

    const bikeRide = await postRide(customerBike.token, 'idem-ride-car-open-bike', 30_000, 'MOTORBIKE');
    const carRide = await postRide(customerCar.token, 'idem-ride-car-open-car', 30_000, 'CAR_4');
    expect(bikeRide.status).toBe(200);
    expect(carRide.status).toBe(200);
    await goOnlineNearPickup(carDriver.token);

    const listed = await request(app.getHttpServer())
      .get('/v1/rides/open')
      .set('Authorization', `Bearer ${carDriver.token}`)
      .expect(200);
    const ids = (listed.body.data as { id: string; vehicleClassCode: string }[]).map((r) => r.id);
    expect(ids).toContain(carRide.body.data.id);
    expect(ids).not.toContain(bikeRide.body.data.id);
    for (const row of listed.body.data as { vehicleClassCode: string }[]) {
      expect(row.vehicleClassCode).toBe('CAR_4');
    }
  });

  it('RIDE-CAR-012: wrong-class driver gets 404 on GET negotiating ride (canRead class gate)', async () => {
    const customer = await login();
    const bikeDriver = await login();
    await repository.insertGrant(bikeDriver.userId, 'DRIVER', 'ACTIVE');

    const created = await postRide(customer.token, 'idem-ride-car-012', 30_000, 'CAR_4');
    expect(created.status).toBe(200);
    const rideId = created.body.data.id as string;

    await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${bikeDriver.token}`)
      .expect(404);

    await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
  });

  it('RIDE-CAR-006: rejects CAR_4 fare below class min (out of range)', async () => {
    const customer = await login();
    // Owner tariff CAR_4 minFareVnd = 20000.
    const denied = await postRide(customer.token, 'idem-ride-car-006-low', 19_000, 'CAR_4');
    expect(denied.status).toBe(400);
    expect(denied.body.errorCode).toBe('RIDE_FARE_OUT_OF_RANGE');
  });

  it('RIDE-CAR-007: rejects CAR_4 fare above class max (out of range)', async () => {
    const customer = await login();
    // DRAFT CAR_4 maxFareVnd is max(platformMax, 800000) with test knobs → 800000.
    const denied = await postRide(customer.token, 'idem-ride-car-007-high', 800_001, 'CAR_4');
    expect(denied.status).toBe(400);
    expect(denied.body.errorCode).toBe('RIDE_FARE_OUT_OF_RANGE');
  });

  it('RIDE-CAR: rejects create when vehicle class is disabled', async () => {
    const customer = await login();
    // Disable CAR_7 via ops path if available; otherwise patch repository seed.
    const listed = await request(app.getHttpServer())
      .post('/v1/rides/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ pickup, dropoff })
      .expect(200);
    const before = (listed.body.data.options as { code: string }[]).map((o) => o.code);
    expect(before).toContain('CAR_7');

    const vehicleClasses = app.get(RideVehicleClassService);
    await vehicleClasses.update('CAR_7', { enabled: false }, 'test-ops');

    const denied = await postRide(customer.token, 'idem-ride-car-disabled', 30_000, 'CAR_7');
    expect(denied.status).toBe(400);
    expect(denied.body.errorCode).toBe('RIDE_VEHICLE_CLASS_UNKNOWN');

    // Restore for later tests in the same suite.
    await vehicleClasses.update('CAR_7', { enabled: true }, 'test-ops');
  });

  it('RIDE-CAR: DRAFT Car reference fare differs from motorbike (ADMIN_EDITABLE seeds)', async () => {
    const customer = await login();
    const quote = await request(app.getHttpServer())
      .post('/v1/rides/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ pickup, dropoff })
      .expect(200);
    const options = quote.body.data.options as {
      code: string;
      referenceFareVnd: number;
    }[];
    const bike = options.find((o) => o.code === 'MOTORBIKE');
    const car4 = options.find((o) => o.code === 'CAR_4');
    expect(bike).toBeDefined();
    expect(car4).toBeDefined();
    // DRAFT seeds: Car should not silently equal bike shared knobs anymore.
    expect(car4!.referenceFareVnd).not.toBe(bike!.referenceFareVnd);
  });

  function postRide(
    token: string,
    idempotencyKey: string,
    offeredFareVnd: number,
    vehicleClassCode = 'MOTORBIKE',
  ) {
    return request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idempotencyKey)
      .send({ pickup, dropoff, offeredFareVnd, vehicleClassCode });
  }

  /** The open list needs a fresh presence fix (DISPATCH_REQUIRE_FRESH_PRESENCE). */
  function goOnlineNearPickup(token: string) {
    return request(app.getHttpServer())
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${token}`)
      .send({ online: true, lat: pickup.lat + 0.001, lng: pickup.lng + 0.001 })
      .expect(200);
  }

  function selectRide(token: string, rideId: string, offerId: string, idempotencyKey: string) {
    return request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idempotencyKey)
      .send({ offerId });
  }
});

describe('ride negotiation in production', () => {
  let app: INestApplication | undefined;
  let sms: MockSmsSender;
  let identity: MemoryIdentityRepository;
  // ConfigModule copies the validated production env (ROUTING_PROVIDER=mapbox, tokens…) into
  // process.env; restore it so the other describe in this file still sees ROUTING_PROVIDER unset.
  const envBefore = { ...process.env };

  beforeAll(async () => {
    sms = new MockSmsSender('test');
    identity = new MemoryIdentityRepository();
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              ...PROD_ENV_OK,
              JWT_ACCESS_SECRET: 'production-test-secret',
              PAYMENT_PROVIDER: 'vnpay',
              VNPAY_TMN_CODE: 'T',
              VNPAY_HASH_SECRET: 'H',
              VNPAY_URL: 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
              RIDE_MIN_FARE_VND: '10000',
              RIDE_MAX_FARE_VND: '500000',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
              PARTNER_ELIGIBILITY_BYPASS: 'false',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        RideModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      // pt5u: partner submit now reads the public legal pages (consent versions).
      .overrideProvider(PUBLIC_PAGES_REPOSITORY)
      .useValue(new MemoryPublicPagesRepository())
      .overrideProvider(DRIVER_PRESENCE_REPOSITORY)
      .useValue(new MemoryDriverPresenceRepository())
      .overrideProvider(AUTH_METHOD_POLICY_REPOSITORY)
      .useValue(new MemoryAuthMethodPolicyRepository())
      .overrideProvider(RIDE_REPOSITORY)
      .useValue(new MemoryRideRepository())
      .overrideProvider(LEDGER_REPOSITORY)
      .useValue(new MemoryLedgerRepository())
      .overrideProvider(PAYMENT_REPOSITORY)
      .useValue(new MemoryPaymentRepository())
      .overrideProvider(CHECKOUT_REPOSITORY)
      .useValue(new MemoryCheckoutRepository())
      .overrideProvider(PARTNER_REPOSITORY)
      .useValue(new MemoryPartnerRepository())
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(await negotiationMechanicsSettings())
      .overrideProvider(RIDE_PICKUP_CODE_STORE)
      .useValue(new MemoryRidePickupCodeStore())
      .overrideProvider(RIDE_CUSTOMER_RATING_STORE)
      .useValue(new MemoryRideCustomerRatingStore())
      .overrideProvider(RIDE_PARCEL_STORE)
      .useValue(new MemoryRideParcelStore())
      .overrideProvider(EARNINGS_REPOSITORY)
      .useValue(new MemoryEarningsRepository())
      .overrideProvider(OPS_FAQ_REPOSITORY)
      .useValue(new MemoryOpsFaqRepository())
      .overrideProvider(OPS_NOTIFICATION_REPOSITORY)
      .useValue(new MemoryOpsNotificationRepository())
      .overrideProvider(PROMOTION_REPOSITORY)
      .useValue(new MemoryPromotionRepository([]))
      .overrideProvider(RIDE_VEHICLE_CLASS_REPOSITORY)
      .useValue(new MemoryRideVehicleClassRepository())
      .overrideProvider(RIDE_ZONE_TARIFF_REPOSITORY)
      .useValue(new MemoryRideZoneTariffRepository())
      .overrideProvider(INTEGRATION_SETTINGS_REPOSITORY)
      .useValue(new MemoryIntegrationSettingsRepository())
      .overrideProvider(EMAIL_SUPPRESSION_REPOSITORY)
      .useValue(new MemoryEmailSuppressionRepository())
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
    for (const key of Object.keys(process.env)) {
      if (!(key in envBefore)) delete process.env[key];
    }
    Object.assign(process.env, envBefore);
  });

  async function phoneLogin(phone: string): Promise<string> {
    const created = await request(app!.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app!.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    return verified.body.data.accessToken as string;
  }

  it('grants CUSTOMER on phone sign-up so a new user can book', async () => {
    const token = await phoneLogin('0918888888');
    const created = await request(app!.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', 'idem-production-ride')
      .send({ pickup, dropoff, offeredFareVnd: 30_000, vehicleClassCode: 'MOTORBIKE' });
    expect(created.status).toBeLessThan(300);
  });

  it('returns ROLE_NOT_ACTIVE for a verified phone user without a customer grant', async () => {
    const legacy = await identity.createUser({
      phone: '+84918888889',
      email: null,
      displayName: 'Legacy user',
    });
    await identity.markPhoneVerified(legacy.id, new Date());
    const token = await phoneLogin('0918888889');

    const denied = await request(app!.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', 'idem-production-ride-legacy')
      .send({ pickup, dropoff, offeredFareVnd: 30_000, vehicleClassCode: 'MOTORBIKE' })
      .expect(403);
    expect(denied.body.errorCode).toBe('ROLE_NOT_ACTIVE');
  });
});
