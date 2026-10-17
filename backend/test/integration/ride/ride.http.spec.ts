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
import { MemoryPlatformSettingsRepository } from '../../../src/platform/settings/platform-settings.repository.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import { MemoryPartnerRepository } from '../../../src/modules/partner/partner.repository.js';
import { PAYMENT_REPOSITORY } from '../../../src/modules/payment/payment.constants.js';
import { MemoryPaymentRepository } from '../../../src/modules/payment/payment.repository.js';
import { haversineKm, quoteReferenceFareVnd } from '../../../src/modules/ride/ride-geo.js';
import { RIDE_CLOCK, RIDE_REPOSITORY, type RideClock } from '../../../src/modules/ride/ride.constants.js';
import { RideModule } from '../../../src/modules/ride/ride.module.js';
import { MemoryRideRepository } from '../../../src/modules/ride/ride.repository.js';

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
  let sms: MockSmsSender;
  let clock: ManualClock;
  let phoneSerial = 100;

  beforeAll(async () => {
    repository = new MemoryIdentityRepository();
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
              PARTNER_ELIGIBILITY_BYPASS: 'true',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        RideModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(repository)
      .overrideProvider(RIDE_CLOCK)
      .useValue(clock)
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
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
      quoteReferenceFareVnd(haversineKm(pickup, dropoff), 8000, 10_000),
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
    const response = await postRide(customer.token, 'idem-fare-too-high', 500_001);
    expect(response.status).toBe(400);
    expect(response.body.errorCode).toBe('RIDE_FARE_OUT_OF_RANGE');
  });

  it('does not upgrade a suspended customer grant', async () => {
    const customer = await login();
    await repository.insertGrant(customer.userId, 'CUSTOMER', 'SUSPENDED');

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
      expiresAt: created.body.data.expiresAt,
      offerCount: 0,
    });
    expect(JSON.stringify(listed.body.data)).not.toContain('"phone"');
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

    const started = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/start`)
      .set('Authorization', `Bearer ${driver.token}`)
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
    expect(opsList.body.data.items.some((ride: { id: string }) => ride.id === rideId)).toBe(true);

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

    const opsLedger = await request(app.getHttpServer())
      .get(`/v1/ops/rides/${rideId}/ledger`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(opsLedger.body.data.id).toBe(journal.body.data.id);
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
      .set('Authorization', `Bearer ${other.token}`);
    expect(denied.status).toBe(403);
    expect(denied.body.errorCode).toBe('RIDE_NOT_ASSIGNED_DRIVER');
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
    await request(app.getHttpServer())
      .post(`/v1/rides/${tripId}/start`)
      .set('Authorization', `Bearer ${againDriver.token}`)
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

  function postRide(token: string, idempotencyKey: string, offeredFareVnd: number) {
    return request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idempotencyKey)
      .send({ pickup, dropoff, offeredFareVnd });
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

  beforeAll(async () => {
    sms = new MockSmsSender('test');
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'production',
              JWT_ACCESS_SECRET: 'production-test-secret',
              SMS_PROVIDER: 'esms',
              PAYMENT_PROVIDER: 'vnpay',
              RIDE_MIN_FARE_VND: '10000',
              RIDE_MAX_FARE_VND: '500000',
              OTP_THROTTLE_LIMIT: '1000',
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
      .useValue(new MemoryIdentityRepository())
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
      .overrideProvider(PARTNER_REPOSITORY)
      .useValue(new MemoryPartnerRepository())
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(new MemoryPlatformSettingsRepository())
      .overrideProvider(OPS_FAQ_REPOSITORY)
      .useValue(new MemoryOpsFaqRepository())
      .overrideProvider(OPS_NOTIFICATION_REPOSITORY)
      .useValue(new MemoryOpsNotificationRepository())
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
  });

  afterAll(async () => {
    await app?.close();
  });

  it('returns ROLE_NOT_ACTIVE when a phone user has no customer grant', async () => {
    const created = await request(app!.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '0918888888' })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app!.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);

    const denied = await request(app!.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${verified.body.data.accessToken}`)
      .set('Idempotency-Key', 'idem-production-ride')
      .send({ pickup, dropoff, offeredFareVnd: 30_000 })
      .expect(403);
    expect(denied.body.errorCode).toBe('ROLE_NOT_ACTIVE');
  });
});
