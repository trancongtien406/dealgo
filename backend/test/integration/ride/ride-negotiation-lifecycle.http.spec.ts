import { seedVehicleClassOnDriverGrant } from '../../support/driver-class-fixture.js';
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
  SMS_SENDER,
} from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { PlatformSettingsService } from '../../../src/platform/settings/platform-settings.service.js';
import { PLATFORM_SETTINGS_REPOSITORY } from '../../../src/platform/settings/platform-settings.constants.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import { MemoryPartnerRepository } from '../../../src/modules/partner/partner.repository.js';
import { haversineKm, quoteReferenceFareVnd } from '../../../src/modules/ride/ride-geo.js';
import {
  rideBidFloorVnd,
  roundDownToFareStep,
  roundUpToFareStep,
} from '../../../src/modules/ride-vehicle/ride-vehicle-class.js';
import { RIDE_CLOCK, type RideClock } from '../../../src/modules/ride/ride.constants.js';
import { RideModule } from '../../../src/modules/ride/ride.module.js';
import { EarningsService } from '../../../src/modules/earnings/earnings.service.js';
import { RideService } from '../../../src/modules/ride/ride.service.js';
import { settingsWith } from '../../support/settings-fixture.js';

const CLOCK_START = new Date('2026-10-13T12:00:00.000Z');
const pickup = { lat: 10.776889, lng: 106.700806, label: 'District 1' };
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
 * bid floor 80 % of reference, counter cap 150 %, 2 offer edits, free cancel 5 min, bike fee
 * 3 000 VND, no-show wait 5 min, assigned/en-route timeouts 5/30 min, debt limit 200 000 VND.
 */
describe('ride negotiation & lifecycle http', () => {
  let app: INestApplication;
  let repository: MemoryIdentityRepository;
  let sms: MockSmsSender;
  let clock: ManualClock;
  let phoneSerial = 5000;
  let reference = 0;

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
      .useValue(await settingsWith({}))
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(repository)
      .overrideProvider(RIDE_CLOCK)
      .useValue(clock)
      .overrideProvider(PARTNER_REPOSITORY)
      .useValue(new MemoryPartnerRepository())
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    seedVehicleClassOnDriverGrant(app, repository);
    reference = roundUpToFareStep(quoteReferenceFareVnd(haversineKm(pickup, dropoff), 5000, 10_000));
  });

  afterAll(async () => {
    await app.close();
  });

  afterEach(() => {
    clock.set(CLOCK_START);
  });

  const http = () => request(app.getHttpServer());
  const bid = () => rideBidFloorVnd(reference, 70) + 1000;

  async function login(): Promise<Actor> {
    phoneSerial += 1;
    const phone = `093${String(phoneSerial).padStart(7, '0')}`;
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

  function postRide(token: string, key: string, offeredFareVnd: number, at = { pickup, dropoff }) {
    return http()
      .post('/v1/rides')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', key)
      .send({ ...at, offeredFareVnd, vehicleClassCode: 'MOTORBIKE' });
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
      .set('Idempotency-Key', `${key}-s`)
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
    expect(bike.referenceFareVnd % 1000).toBe(0);
    expect(bike.minBidVnd).toBe(Math.max(bike.minFareVnd, rideBidFloorVnd(bike.referenceFareVnd, 70)));
    expect(bike.minBidVnd % 1000).toBe(0);
    expect(quote.body.data.pendingFeesVnd).toBe(0);

    const low = await postRide(customer.token, 'ride-neg-floor-low', bike.minBidVnd - 1000);
    expect(low.status).toBe(400);
    expect(low.body.errorCode).toBe('RIDE_FARE_OUT_OF_RANGE');
    // An odd bid just under the floor rounds up to the floor and is stored rounded.
    const ok = await postRide(customer.token, 'ride-neg-floor-ok', bike.minBidVnd - 1).expect(200);
    expect(ok.body.data.offeredFareVnd).toBe(bike.minBidVnd);
    // window = RIDE_REQUEST_WINDOW_SECONDS (300), not the 60 s offer TTL
    expect(new Date(ok.body.data.expiresAt).getTime() - CLOCK_START.getTime()).toBe(300_000);
  });

  it('rejects a counter above 150% of the bid and one below the bid', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = (await postRide(customer.token, 'ride-neg-counter', bid()).expect(200)).body.data.id;
    // Within one fare step above the cap the counter is clamped to the cap
    // (stepFareWithinCap); a full step above it is rejected.
    const high = await offer(d.token, rideId, roundDownToFareStep(bid() * 1.5) + 1000);
    expect(high.status).toBe(400);
    expect(high.body.errorCode).toBe('RIDE_COUNTER_OUT_OF_RANGE');
    const under = await offer(d.token, rideId, bid() - 1000);
    expect(under.status).toBe(400);
    const cap = roundDownToFareStep(bid() * 1.5);
    const top = await offer(d.token, rideId, cap - 1).expect(200);
    // An odd counter is stored rounded up to the 1.000đ step.
    expect(top.body.data.offers[0].amountVnd).toBe(cap);
  });

  it('caps offer edits per driver (RIDE_MAX_OFFER_EDITS_PER_DRIVER = 2)', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = (await postRide(customer.token, 'ride-neg-edits', bid()).expect(200)).body.data.id;
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
    const created = await postRide(customer.token, 'ride-neg-raise', bid()).expect(200);
    const rideId = created.body.data.id;
    await offer(d.token, rideId, bid() + 2000).expect(200);
    clock.advanceSeconds(120);
    const same = await post(customer.token, `/v1/rides/${rideId}/fare`, { amountVnd: bid() });
    expect(same.status).toBe(400);
    expect(same.body.errorCode).toBe('RIDE_FARE_RAISE_INVALID');
    const raised = await post(customer.token, `/v1/rides/${rideId}/fare`, { amountVnd: bid() + 5000 }).expect(200);
    expect(raised.body.data.offeredFareVnd).toBe(bid() + 5000);
    const odd = await post(customer.token, `/v1/rides/${rideId}/fare`, { amountVnd: bid() + 6001 }).expect(200);
    expect(odd.body.data.offeredFareVnd).toBe(bid() + 7000);
    expect(raised.body.data.offers[0]).toMatchObject({ amountVnd: bid() + 5000, kind: 'ACCEPT' });
    expect(new Date(raised.body.data.expiresAt).getTime()).toBe(CLOCK_START.getTime() + 420_000);
    const stranger = await login();
    await post(stranger.token, `/v1/rides/${rideId}/fare`, { amountVnd: bid() + 9000 }).expect(404);
  });

  it('customer declines an offer; that driver cannot bid again on the ride', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = (await postRide(customer.token, 'ride-neg-decline', bid()).expect(200)).body.data.id;
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
    const rideId = (await postRide(customer.token, 'ride-neg-withdraw', bid()).expect(200)).body.data.id;
    const offered = await offer(d.token, rideId, bid()).expect(200);
    const withdrawn = await post(d.token, `/v1/rides/${rideId}/offers/withdraw`).expect(200);
    expect(withdrawn.body.data.offers[0].status).toBe('WITHDRAWN');
    const select = await http()
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'ride-neg-withdraw-s')
      .send({ offerId: offered.body.data.offers[0].id });
    expect(select.status).toBe(409);
    await post(d.token, `/v1/rides/${rideId}/offers/withdraw`).expect(409);
  });

  // --- driver cancel, late cancel fee, no-show ---
  it('driver cancel needs a reason and returns the ride to bidding with a fresh window', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = await assigned(customer, d, 'ride-neg-dcancel');
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
    const free = await assigned(customer, d, 'ride-neg-free');
    clock.advanceSeconds(4 * 60);
    await post(customer.token, `/v1/rides/${free}/cancel`).expect(200);
    expect((await get(customer.token, '/v1/rides/pending-fees').expect(200)).body.data.pendingFeesVnd).toBe(0);

    const late = await assigned(customer, d, 'ride-neg-late');
    clock.advanceSeconds(5 * 60);
    await post(customer.token, `/v1/rides/${late}/cancel`).expect(200);
    expect((await get(customer.token, '/v1/rides/pending-fees').expect(200)).body.data.pendingFeesVnd).toBe(3000);
  });

  it('no-show after the wait: fee owed, collected in the next ride cash and passed to the waiting driver', async () => {
    const customer = await login();
    const waited = await driver();
    const rideId = await arrived(customer, waited, 'ride-neg-noshow');
    const early = await post(waited.token, `/v1/rides/${rideId}/no-show`);
    expect(early.status).toBe(409);
    expect(early.body.errorCode).toBe('RIDE_NO_SHOW_TOO_EARLY');
    clock.advanceSeconds(5 * 60);
    const done = await post(waited.token, `/v1/rides/${rideId}/no-show`).expect(200);
    expect(done.body.data).toMatchObject({ status: 'CANCELLED', noShow: true, cancelReasonCode: 'NO_SHOW' });
    expect((await get(customer.token, '/v1/rides/pending-fees').expect(200)).body.data.pendingFeesVnd).toBe(3000);

    // Next ride with another driver: cash due includes the fee, handed over via adjustments.
    const collector = await driver();
    const next = await assigned(customer, collector, 'ride-neg-noshow-next');
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
    const rideId = await assigned(customer, d, 'ride-neg-timeout');
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
    const created = await postRide(customer.token, 'ride-neg-open', bid()).expect(200);
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
    const res = await postRide(customer.token, 'ride-neg-zone', bid(), { pickup: planned, dropoff });
    expect(res.status).toBe(422);
    expect(res.body.errorCode).toBe('RIDE_OUTSIDE_SERVICE_ZONE');
  });

  // t71u: city product stays in one active region (HN→DN rejected, HN→HN allowed).
  it('rejects a pickup and drop-off in different active regions with RIDE_CROSS_REGION_NOT_SUPPORTED', async () => {
    const customer = await login();
    const hanoi = { lat: 21.0285, lng: 105.8542, label: 'Hoan Kiem' };
    const hanoiWest = { lat: 21.038, lng: 105.782, label: 'Cau Giay' };
    const danang = { lat: 16.0612, lng: 108.228, label: 'Cau Rong' };
    const cross = await postRide(customer.token, 'ride-neg-cross', bid(), { pickup: hanoi, dropoff: danang });
    expect(cross.status).toBe(422);
    expect(cross.body.errorCode).toBe('RIDE_CROSS_REGION_NOT_SUPPORTED');
    const quote = await request(app.getHttpServer())
      .post('/v1/rides/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ pickup: hanoi, dropoff: danang });
    expect(quote.status).toBe(422);
    expect(quote.body.errorCode).toBe('RIDE_CROSS_REGION_NOT_SUPPORTED');
    const outside = { lat: 12.2388, lng: 109.1967, label: 'Nha Trang' };
    const far = await postRide(customer.token, 'ride-neg-cross-out', bid(), { pickup: hanoi, dropoff: outside });
    expect(far.body.errorCode).toBe('RIDE_OUTSIDE_SERVICE_ZONE');
    const local = await postRide(customer.token, 'ride-neg-local', bid(), { pickup: hanoi, dropoff: hanoiWest });
    expect(local.body.errorCode).not.toBe('RIDE_CROSS_REGION_NOT_SUPPORTED');
    expect(local.body.errorCode).not.toBe('RIDE_OUTSIDE_SERVICE_ZONE');
  });

  // t73u: with RIDE_INTERCITY_ENABLED a cross-region trip is a Liên tỉnh booking (bike and car).
  it('turns a cross-region trip into an intercity booking when ops enable it', async () => {
    const repo = app.get(PLATFORM_SETTINGS_REPOSITORY);
    const settings = app.get(PlatformSettingsService);
    const toggle = async (value: string) => {
      await repo.upsert({
        key: 'RIDE_INTERCITY_ENABLED',
        value,
        valueType: 'json',
        updatedByUserId: null,
        reason: 'test',
        previousValue: null,
      });
      settings.invalidateCache();
    };
    await toggle('true');
    try {
      const customer = await login();
      const hanoi = { lat: 21.0285, lng: 105.8542, label: 'Hoan Kiem' };
      const danang = { lat: 16.0612, lng: 108.228, label: 'Cau Rong' };
      const outside = { lat: 12.2388, lng: 109.1967, label: 'Nha Trang' };
      const quote = await request(app.getHttpServer())
        .post('/v1/rides/quote')
        .set('Authorization', `Bearer ${customer.token}`)
        .send({ pickup: hanoi, dropoff: outside });
      if (quote.status === 200) {
        expect(quote.body.data.intercity).toBe(true);
      } else {
        expect(quote.body.errorCode).toBe('RIDE_INTERCITY_NO_VEHICLE');
      }
      const bike = await postRide(customer.token, 'ride-intercity-bike', bid(), { pickup: hanoi, dropoff: danang });
      expect(bike.body.errorCode).not.toBe('RIDE_INTERCITY_VEHICLE_NOT_ALLOWED');
      expect(bike.body.errorCode).not.toBe('RIDE_CROSS_REGION_NOT_SUPPORTED');
      const unserved = await postRide(customer.token, 'ride-intercity-out', bid(), { pickup: outside, dropoff: hanoi });
      expect(unserved.body.errorCode).toBe('RIDE_OUTSIDE_SERVICE_ZONE');
    } finally {
      await toggle('false');
    }
  });

  // --- P1: debt limit ---
  it('blocks a driver over DRIVER_DEBT_LIMIT_VND from the open list and from bidding', async () => {
    const customer = await login();
    const rideId = (await postRide(customer.token, 'ride-neg-debt', bid()).expect(200)).body.data.id;
    const d = await driver();
    await app.get(EarningsService).adjustWithin(undefined as never, {
      driverId: d.userId,
      amountVnd: 200_001,
      kind: 'MANUAL',
      refType: 'TEST',
      refId: 'debt-1',
      occurredAt: CLOCK_START,
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
    const rideId = await arrived(customer, d, 'ride-neg-rate');
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

    await postRide(customer.token, 'ride-neg-rate-next', bid()).expect(200);
    const another = await driver();
    const listed = await get(another.token, '/v1/rides/open').expect(200);
    const mine = listed.body.data.find((r: { offeredFareVnd: number; customerRating: { count: number } }) =>
      r.customerRating.count === 1,
    );
    expect(mine.customerRating).toEqual({ average: 4, count: 1 });
  });
});
