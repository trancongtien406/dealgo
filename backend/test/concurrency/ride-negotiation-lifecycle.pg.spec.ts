/**
 * ride negotiation & lifecycle against Postgres — the same scenarios as
 * test/integration/ride/ride-negotiation-lifecycle.http.spec.ts, but through the Prisma repositories and the
 * migrated DRAFT settings rows (no memory overrides except SMS + clock).
 * Skips when DATABASE_URL is unset.
 */
import { randomUUID } from 'node:crypto';
import { uniqueTestPhone } from './test-phone.js';
import { seedVehicleClassOnDriverGrant } from '../support/driver-class-fixture.js';
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
import { MockSmsSender } from '../../src/integrations/sms/sms-sender.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { RIDE_CLOCK, type RideClock } from '../../src/modules/ride/ride.constants.js';
import { RideModule } from '../../src/modules/ride/ride.module.js';
import {
  clampToFareSteps,
  RIDE_FARE_ROUNDING_STEP_VND,
  roundDownToFareStep,
} from '../../src/modules/ride-vehicle/ride-vehicle-class.js';
import { EarningsService } from '../../src/modules/earnings/earnings.service.js';
import { RideService } from '../../src/modules/ride/ride.service.js';
import { PlatformSettingsService } from '../../src/platform/settings/platform-settings.service.js';
import { PARTNER_REPOSITORY } from '../../src/modules/partner/partner.constants.js';
import type { PartnerRepository } from '../../src/modules/partner/partner.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;
const RUN = `pg-${Date.now()}-${randomUUID().slice(0, 6)}`;

// Real "now" (rounded): presence rows are stamped by Postgres, so the ride clock must be near them.
const CLOCK_START = new Date(Math.floor(Date.now() / 1000) * 1000);
// Per-run pickup jitter (±~2 km): earlier runs leave open rides in the shared dev DB at the
// same point, and equal distances would push this run's rides past the 20-row open-list cap.
const jitter = () => (Math.random() - 0.5) * 0.04;
const pickup = { lat: 10.776889 + jitter(), lng: 106.700806 + jitter(), label: 'District 1' };
const dropoff = { lat: 10.823099, lng: 106.629664, label: 'Airport' };

class ManualClock implements RideClock {
  constructor(private current: Date) {}
  now(): Date {
    return new Date(this.current);
  }
  set(next: Date): void {
    this.current = next;
  }
  advanceSeconds(seconds: number): void {
    this.current = new Date(this.current.getTime() + seconds * 1000);
  }
}

type Actor = { token: string; userId: string };

/**
 * Behaviour over HTTP with catalog defaults (DRAFT values): request window 300 s,
 * bid floor (setting, 70 % since DEC-PROD-069) of reference, counter cap 150 %, 2 offer edits, free cancel 5 min, bike fee
 * 3 000 VND, no-show wait 5 min, assigned/en-route timeouts 5/30 min, debt limit 200 000 VND.
 */
describePg('ride negotiation & lifecycle (postgres)', () => {
  let app: INestApplication;
  let repository: { insertGrant: (u: string, r: 'DRIVER', s: 'ACTIVE') => Promise<unknown> };
  let sms: MockSmsSender;
  let clock: ManualClock;
    let reference = 0; // = MOTORBIKE minBidVnd here

  beforeAll(async () => {
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
              DATABASE_URL: process.env.DATABASE_URL,
              PUSH_PROVIDER: 'mock',
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
        PrismaModule,
        RideModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(RIDE_CLOCK)
      .useValue(clock)
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    repository = app.get(IDENTITY_REPOSITORY);
    seedVehicleClassOnDriverGrant(app, repository);
    // DB vehicle classes carry their own per-km price: take the floor from the live quote.
    const probe = await login();
    const quote = await http().post('/v1/rides/quote').set('Authorization', `Bearer ${probe.token}`).send({ pickup, dropoff }).expect(200);
    reference = quote.body.data.options.find((o: { code: string }) => o.code === 'MOTORBIKE').minBidVnd;
  });

  afterAll(async () => {
    await app.close();
  });

  afterEach(() => {
    clock.set(CLOCK_START);
  });

  const http = () => request(app.getHttpServer());
  const bid = () => reference + 1000;

  async function login(): Promise<Actor> {
    const phone = uniqueTestPhone();
    const created = await http().post('/v1/auth/phone/challenges').send({ phone }).expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await http()
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    return { token: verified.body.data.accessToken, userId: verified.body.data.user.id };
  }

  async function driver(): Promise<Actor> {
    const d = await login();
    await repository.insertGrant(d.userId, 'DRIVER', 'ACTIVE');
    await http()
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${d.token}`)
      .send({ online: true, lat: pickup.lat + 0.002, lng: pickup.lng + 0.002 })
      .expect(200);
    return d;
  }

  function postRide(
    token: string,
    key: string,
    offeredFareVnd: number,
    at = { pickup, dropoff },
    vehicleClassCode = 'MOTORBIKE',
  ) {
    return http()
      .post('/v1/rides')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `${RUN}-${key}`)
      .send({ ...at, offeredFareVnd, vehicleClassCode });
  }

  function offer(token: string, rideId: string, amountVnd: number) {
    return http().post(`/v1/rides/${rideId}/offers`).set('Authorization', `Bearer ${token}`).send({ amountVnd });
  }

  function post(token: string, path: string, body: object = {}) {
    return http().post(path).set('Authorization', `Bearer ${token}`).send(body);
  }

  function get(token: string, path: string) {
    return http().get(path).set('Authorization', `Bearer ${token}`);
  }

  async function assigned(customer: Actor, d: Actor, key: string): Promise<string> {
    const created = await postRide(customer.token, `${key}-c`, bid()).expect(200);
    const rideId = created.body.data.id as string;
    const offered = await offer(d.token, rideId, bid()).expect(200);
    await http()
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `${RUN}-${key}-s`)
      .send({ offerId: offered.body.data.offers[0].id })
      .expect(200);
    return rideId;
  }

  async function arrived(customer: Actor, d: Actor, key: string): Promise<string> {
    const rideId = await assigned(customer, d, key);
    await post(d.token, `/v1/rides/${rideId}/en-route`).expect(200);
    await post(d.token, `/v1/rides/${rideId}/arrived`).expect(200);
    return rideId;
  }

  async function complete(customer: Actor, d: Actor, rideId: string) {
    const code = (await get(customer.token, `/v1/rides/${rideId}`).expect(200)).body.data.pickupCode;
    await post(d.token, `/v1/rides/${rideId}/start`, { pickupCode: code }).expect(200);
    return post(d.token, `/v1/rides/${rideId}/complete`).expect(200);
  }

  // --- price bounds and request window ---
  it('quote exposes the effective minimum bid; create rejects a bid under the floor', async () => {
    const customer = await login();
    const quote = await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200);
    const bike = quote.body.data.options.find((o: { code: string }) => o.code === 'MOTORBIKE');
    // The floor (RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE, 70% since DEC-PROD-069) is rounded up to
    // the fare step and kept inside the class bounds. Read live so a settings change can't stale it.
    const floorPct = await app
      .get(PlatformSettingsService, { strict: false })
      .getNumber('RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE');
    expect(bike.minBidVnd).toBe(
      clampToFareSteps(
        Math.max(bike.minFareVnd, Math.ceil((bike.referenceFareVnd * floorPct) / 100)),
        bike.minFareVnd,
        bike.maxFareVnd,
      ),
    );
    expect(quote.body.data.pendingFeesVnd).toBe(0);

    // A bid is rounded up to the fare step, so one step below the floor is the first rejected bid.
    const low = await postRide(customer.token, 'floor-low', bike.minBidVnd - RIDE_FARE_ROUNDING_STEP_VND);
    expect(low.status).toBe(400);
    expect(low.body.errorCode).toBe('RIDE_FARE_OUT_OF_RANGE');
    const ok = await postRide(customer.token, 'floor-ok', bike.minBidVnd).expect(200);
    // window = RIDE_REQUEST_WINDOW_SECONDS (300), not the 60 s offer TTL
    expect(new Date(ok.body.data.expiresAt).getTime() - CLOCK_START.getTime()).toBe(300_000);
  });

  it('rejects a counter above 150% of the bid and one below the bid', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = (await postRide(customer.token, 'counter', bid()).expect(200)).body.data.id;
    // Counters are rounded up to the fare step; the cap is 150% rounded down to the step.
    const cap = Math.max(bid(), roundDownToFareStep(bid() * 1.5));
    const high = await offer(d.token, rideId, cap + RIDE_FARE_ROUNDING_STEP_VND);
    expect(high.status).toBe(400);
    expect(high.body.errorCode).toBe('RIDE_COUNTER_OUT_OF_RANGE');
    const under = await offer(d.token, rideId, bid() - RIDE_FARE_ROUNDING_STEP_VND);
    expect(under.status).toBe(400);
    await offer(d.token, rideId, cap).expect(200);
  });

  it('caps offer edits per driver (RIDE_MAX_OFFER_EDITS_PER_DRIVER = 2)', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = (await postRide(customer.token, 'edits', bid()).expect(200)).body.data.id;
    await offer(d.token, rideId, bid() + 1000).expect(200);
    await offer(d.token, rideId, bid() + 2000).expect(200);
    const second = await offer(d.token, rideId, bid() + 3000).expect(200);
    expect(second.body.data.offers[0].editCount).toBe(2);
    const third = await offer(d.token, rideId, bid() + 4000);
    expect(third.status).toBe(409);
    expect(third.body.errorCode).toBe('RIDE_OFFER_EDIT_LIMIT');
  });

  // --- raise fare, decline, withdraw ---
  it('customer raises the fare: lower offers become ACCEPT at the new price, window extends', async () => {
    const customer = await login();
    const d = await driver();
    const created = await postRide(customer.token, 'raise', bid()).expect(200);
    const rideId = created.body.data.id;
    await offer(d.token, rideId, bid() + 2000).expect(200);
    clock.advanceSeconds(120);
    const same = await post(customer.token, `/v1/rides/${rideId}/fare`, { amountVnd: bid() });
    expect(same.status).toBe(400);
    expect(same.body.errorCode).toBe('RIDE_FARE_RAISE_INVALID');
    const raised = await post(customer.token, `/v1/rides/${rideId}/fare`, { amountVnd: bid() + 5000 }).expect(200);
    expect(raised.body.data.offeredFareVnd).toBe(bid() + 5000);
    expect(raised.body.data.offers[0]).toMatchObject({ amountVnd: bid() + 5000, kind: 'ACCEPT' });
    expect(new Date(raised.body.data.expiresAt).getTime()).toBe(CLOCK_START.getTime() + 420_000);
    const stranger = await login();
    await post(stranger.token, `/v1/rides/${rideId}/fare`, { amountVnd: bid() + 9000 }).expect(404);
  });

  it('customer declines an offer; that driver cannot bid again on the ride', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = (await postRide(customer.token, 'decline', bid()).expect(200)).body.data.id;
    const offered = await offer(d.token, rideId, bid()).expect(200);
    const declined = await post(customer.token, `/v1/rides/${rideId}/offers/decline`, {
      offerId: offered.body.data.offers[0].id,
    }).expect(200);
    expect(declined.body.data.offers[0].status).toBe('DECLINED');
    const again = await offer(d.token, rideId, bid() + 1000);
    expect(again.status).toBe(409);
    expect(again.body.errorCode).toBe('RIDE_OFFER_DECLINED');
  });

  it('driver withdraws an offer and the customer can no longer select it', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = (await postRide(customer.token, 'withdraw', bid()).expect(200)).body.data.id;
    const offered = await offer(d.token, rideId, bid()).expect(200);
    const withdrawn = await post(d.token, `/v1/rides/${rideId}/offers/withdraw`).expect(200);
    expect(withdrawn.body.data.offers[0].status).toBe('WITHDRAWN');
    const select = await http()
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `${RUN}-withdraw-s`)
      .send({ offerId: offered.body.data.offers[0].id });
    expect(select.status).toBe(409);
    await post(d.token, `/v1/rides/${rideId}/offers/withdraw`).expect(409);
  });

  // --- driver cancel, late cancel fee, no-show ---
  it('driver cancel needs a reason and returns the ride to bidding with a fresh window', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = await assigned(customer, d, 'dcancel');
    await post(d.token, `/v1/rides/${rideId}/driver-cancel`, {}).expect(400);
    await post(d.token, `/v1/rides/${rideId}/driver-cancel`, { reasonCode: 'NOPE' }).expect(400);
    clock.advanceSeconds(60);
    await post(d.token, `/v1/rides/${rideId}/driver-cancel`, { reasonCode: 'VEHICLE_PROBLEM' }).expect(200);
    const view = await get(customer.token, `/v1/rides/${rideId}`).expect(200);
    expect(view.body.data.status).toBe('NEGOTIATING');
    expect(view.body.data.assignedDriverId).toBeNull();
    expect(new Date(view.body.data.expiresAt).getTime()).toBe(CLOCK_START.getTime() + 360_000);
    const other = await login();
    const otherDriver = await login();
    await post(otherDriver.token, `/v1/rides/${rideId}/driver-cancel`, { reasonCode: 'OTHER' }).expect(403);
    expect(other.userId).toBeTruthy();
  });

  it('cancel is free inside RIDE_FREE_CANCEL_MINUTES and costs the bike fee after', async () => {
    const customer = await login();
    const d = await driver();
    const free = await assigned(customer, d, 'free');
    clock.advanceSeconds(4 * 60);
    await post(customer.token, `/v1/rides/${free}/cancel`).expect(200);
    expect((await get(customer.token, '/v1/rides/pending-fees').expect(200)).body.data.pendingFeesVnd).toBe(0);

    const late = await assigned(customer, d, 'late');
    clock.advanceSeconds(5 * 60);
    await post(customer.token, `/v1/rides/${late}/cancel`).expect(200);
    expect((await get(customer.token, '/v1/rides/pending-fees').expect(200)).body.data.pendingFeesVnd).toBe(3000);
  });

  it('no-show after the wait: fee owed, collected in the next ride cash and passed to the waiting driver', async () => {
    const customer = await login();
    const waited = await driver();
    const rideId = await arrived(customer, waited, 'noshow');
    const early = await post(waited.token, `/v1/rides/${rideId}/no-show`);
    expect(early.status).toBe(409);
    expect(early.body.errorCode).toBe('RIDE_NO_SHOW_TOO_EARLY');
    clock.advanceSeconds(5 * 60);
    const done = await post(waited.token, `/v1/rides/${rideId}/no-show`).expect(200);
    expect(done.body.data).toMatchObject({ status: 'CANCELLED', noShow: true, cancelReasonCode: 'NO_SHOW' });
    expect((await get(customer.token, '/v1/rides/pending-fees').expect(200)).body.data.pendingFeesVnd).toBe(3000);

    // Next ride with another driver: cash due includes the fee, handed over via adjustments.
    const collector = await driver();
    const next = await assigned(customer, collector, 'noshow-next');
    await post(collector.token, `/v1/rides/${next}/en-route`).expect(200);
    await post(collector.token, `/v1/rides/${next}/arrived`).expect(200);
    const completed = await complete(customer, collector, next);
    expect(completed.body.data.priorFeesVnd).toBe(3000);
    expect((await get(customer.token, '/v1/rides/pending-fees').expect(200)).body.data.pendingFeesVnd).toBe(0);
    const earnings = app.get(EarningsService);
    const owed = await earnings.listAdjustments(collector.userId);
    const credit = await earnings.listAdjustments(waited.userId);
    expect(owed.map((a) => [a.kind, a.amountVnd])).toEqual([['CUSTOMER_FEE_COLLECTED', 3000]]);
    expect(credit.map((a) => [a.kind, a.amountVnd])).toEqual([['CUSTOMER_FEE_PAYOUT', -3000]]);
  });

  // --- assigned/en-route timeouts ---
  it('timeoutDue returns a never-started ride to bidding after 5 minutes', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = await assigned(customer, d, 'timeout');
    const rides = app.get(RideService);
    expect((await rides.timeoutDue(new Date(CLOCK_START.getTime() + 4 * 60_000))).returnedIds).not.toContain(rideId);
    clock.advanceSeconds(5 * 60 + 1);
    expect((await rides.timeoutDue()).returnedIds).toContain(rideId);
    const view = await get(customer.token, `/v1/rides/${rideId}`).expect(200);
    expect(view.body.data.status).toBe('NEGOTIATING');
  });

  // --- open list needs a fresh fix and is radius-filtered ---
  it('open list: stale presence is 409, far rides are hidden, nearest first with distance', async () => {
    const customer = await login();
    const created = await postRide(customer.token, 'open', bid()).expect(200);
    const noFix = await login();
    await repository.insertGrant(noFix.userId, 'DRIVER', 'ACTIVE');
    await post(noFix.token, '/v1/me/presence', { online: true }).expect(200);
    const stale = await get(noFix.token, '/v1/rides/open');
    expect(stale.status).toBe(409);
    expect(stale.body.errorCode).toBe('DRIVER_LOCATION_STALE');

    const near = await driver();
    const listed = await get(near.token, '/v1/rides/open').expect(200);
    const row = listed.body.data.find((r: { id: string }) => r.id === created.body.data.id);
    expect(row.pickupDistanceKm).toBeLessThan(1);
    expect(row.customerRating).toEqual({ average: null, count: 0 });

    // Hanoi is ~1 100 km away: never the old "recent rides anywhere" fallback.
    const far = await get(near.token, '/v1/rides/open?lat=21.0278&lng=105.8342').expect(200);
    expect(far.body.data.find((r: { id: string }) => r.id === created.body.data.id)).toBeUndefined();
  });

  // --- service zone ---
  it('rejects pickup/drop-off outside an ACTIVE service region', async () => {
    const customer = await login();
    const planned = { lat: 10.0452, lng: 105.7469, label: 'Can Tho' };
    const res = await postRide(customer.token, 'zone', bid(), { pickup: planned, dropoff });
    expect(res.status).toBe(422);
    expect(res.body.errorCode).toBe('RIDE_OUTSIDE_SERVICE_ZONE');
  });

  // --- P1: debt limit ---
  it('blocks a driver over DRIVER_DEBT_LIMIT_VND from the open list and from bidding', async () => {
    const customer = await login();
    const rideId = (await postRide(customer.token, 'debt', bid()).expect(200)).body.data.id;
    const d = await driver();
    await app.get(EarningsService).adjustWithin(undefined as never, {
      driverId: d.userId,
      amountVnd: 200_001,
      kind: 'MANUAL',
      refType: 'TEST',
      refId: randomUUID(),
      occurredAt: new Date(),
    });
    const listed = await get(d.token, '/v1/rides/open');
    expect(listed.status).toBe(403);
    expect(listed.body.errorCode).toBe('DRIVER_DEBT_LIMIT_REACHED');
    expect((await offer(d.token, rideId, bid())).status).toBe(403);
  });

  // --- P1: driver rates customer ---
  it('driver rates the customer once after completion; drivers then see the average', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = await arrived(customer, d, 'rate');
    await post(d.token, `/v1/rides/${rideId}/customer-rating`, { stars: 5 }).expect(422);
    await complete(customer, d, rideId);
    await post(d.token, `/v1/rides/${rideId}/customer-rating`, { stars: 6 }).expect(400);
    await post(d.token, `/v1/rides/${rideId}/customer-rating`, { stars: 4, tags: ['BAD_TAG'] }).expect(400);
    const rated = await post(d.token, `/v1/rides/${rideId}/customer-rating`, {
      stars: 4,
      tags: ['POLITE', 'POLITE'],
      comment: 'ok',
    }).expect(201);
    expect(rated.body.data).toMatchObject({ stars: 4, tags: ['POLITE'] });
    const dup = await post(d.token, `/v1/rides/${rideId}/customer-rating`, { stars: 5 });
    expect(dup.status).toBe(409);
    expect(dup.body.errorCode).toBe('RIDE_ALREADY_RATED');
    await post(customer.token, `/v1/rides/${rideId}/customer-rating`, { stars: 1 }).expect(403);

    const snap = await get(d.token, `/v1/rides/${rideId}/customer-rating`).expect(200);
    expect(snap.body.data.customer).toEqual({ average: 4, count: 1 });

    const nextId = (await postRide(customer.token, 'rate-next', bid()).expect(200)).body.data.id;
    const another = await driver();
    const listed = await get(another.token, '/v1/rides/open').expect(200);
    const mine = listed.body.data.find((r: { id: string }) => r.id === nextId);
    expect(mine.customerRating).toEqual({ average: 4, count: 1 });
  });

  // --- Commission per vehicle class (RIDE_COMMISSION_BIKE/CAR_PERCENT) ---
  it('snapshots the motorbike or car commission on completion', async () => {
    const settings = app.get(PlatformSettingsService, { strict: false });
    const earnings = app.get(EarningsService, { strict: false });
    const customer = await login();
    const admin = customer.userId;
    const before = {
      bike: String(await settings.getNumber('RIDE_COMMISSION_BIKE_PERCENT')),
      car: String(await settings.getNumber('RIDE_COMMISSION_CAR_PERCENT')),
    };
    await settings.patch('RIDE_COMMISSION_BIKE_PERCENT', '10', 'pg test TEST_ONLY', admin);
    await settings.patch('RIDE_COMMISSION_CAR_PERCENT', '15', 'pg test TEST_ONLY', admin);
    try {
      const bikeDriver = await driver();
      const bikeRide = await arrived(customer, bikeDriver, 'bike');
      await complete(customer, bikeDriver, bikeRide);

      const carDriver = await driver();
      const partners = app.get<PartnerRepository>(PARTNER_REPOSITORY, { strict: false });
      await partners.upsertSubmit({
        id: randomUUID(),
        userId: carDriver.userId,
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'CAR_4' },
        documents: [],
        now: new Date(),
      });
      const quote = await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200);
      const car = quote.body.data.options.find((o: { code: string }) => o.code === 'CAR_4');
      const carBid = (car.minBidVnd as number) + 1000;
      const created = await postRide(customer.token, 'car', carBid, { pickup, dropoff }, 'CAR_4').expect(200);
      const carRide = created.body.data.id as string;
      const offered = await offer(carDriver.token, carRide, carBid).expect(200);
      await http()
        .post(`/v1/rides/${carRide}/selection`)
        .set('Authorization', `Bearer ${customer.token}`)
        .set('Idempotency-Key', `${RUN}-car-s`)
        .send({ offerId: offered.body.data.offers[0].id })
        .expect(200);
      await post(carDriver.token, `/v1/rides/${carRide}/en-route`).expect(200);
      await post(carDriver.token, `/v1/rides/${carRide}/arrived`).expect(200);
      await complete(customer, carDriver, carRide);

      const map = await earnings.findMany([
        { entityType: 'RIDE', entityId: bikeRide },
        { entityType: 'RIDE', entityId: carRide },
      ]);
      expect(map.get(`RIDE:${bikeRide}`)).toMatchObject({ feeBps: 1000 });
      expect(map.get(`RIDE:${carRide}`)).toMatchObject({ feeBps: 1500 });
    } finally {
      await settings.patch('RIDE_COMMISSION_BIKE_PERCENT', before.bike, 'pg test reset', admin);
      await settings.patch('RIDE_COMMISSION_CAR_PERCENT', before.car, 'pg test reset', admin);
    }
  });
});
