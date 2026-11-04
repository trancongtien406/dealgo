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
import { PLATFORM_SETTINGS_REPOSITORY } from '../../../src/platform/settings/platform-settings.constants.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import { MemoryPartnerRepository } from '../../../src/modules/partner/partner.repository.js';
import { RIDE_CLOCK, type RideClock } from '../../../src/modules/ride/ride.constants.js';
import { RideModule } from '../../../src/modules/ride/ride.module.js';
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
describe('ride multi-stop http', () => {
  let app: INestApplication;
  let repository: MemoryIdentityRepository;
  let sms: MockSmsSender;
  let clock: ManualClock;
  let phoneSerial = 7000;

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
      .useValue(
        await settingsWith({
          RIDE_MULTI_STOP_BIKE_ENABLED: true,
          RIDE_MAX_STOPS_BIKE: 2,
          RIDE_STOP_FEE_BIKE_VND: 5000,
          RIDE_MULTI_STOP_CAR_ENABLED: false,
          RIDE_STOP_FREE_WAIT_MINUTES: 5,
          RIDE_STOP_WAIT_FEE_VND_PER_MINUTE: 1000,
          RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE: 0,
        }),
      )
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
  });

  afterAll(async () => {
    await app.close();
  });

  afterEach(() => {
    clock.set(CLOCK_START);
  });

  const http = () => request(app.getHttpServer());

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

  const stopA = { lat: 10.79, lng: 106.68, label: 'Stop A' };
  const stopB = { lat: 10.80, lng: 106.66, label: 'Stop B' };

  function postRide(token: string, key: string, offeredFareVnd: number, stops: object[] = [], vehicleClassCode = 'MOTORBIKE') {
    return http()
      .post('/v1/rides')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', key)
      .send({ pickup, dropoff, stops, offeredFareVnd, vehicleClassCode });
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


  it('config endpoint reflects the admin flags', async () => {
    const customer = await login();
    const res = await get(customer.token, '/v1/rides/multi-stop-config').expect(200);
    expect(res.body.data.BIKE).toMatchObject({ enabled: true, maxStops: 2, stopFeeVnd: 5000 });
    expect(res.body.data.CAR).toMatchObject({ enabled: false, maxStops: 0 });
  });

  it('quote with stops adds the stop fee and marks disabled services unavailable', async () => {
    const customer = await login();
    const plain = await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200);
    const multi = await post(customer.token, '/v1/rides/quote', { pickup, dropoff, stops: [stopA] }).expect(200);
    const bikePlain = plain.body.data.options.find((o: { code: string }) => o.code === 'MOTORBIKE');
    const bikeMulti = multi.body.data.options.find((o: { code: string }) => o.code === 'MOTORBIKE');
    expect(bikePlain.available).toBe(true);
    expect(bikeMulti.available).toBe(true);
    expect(bikeMulti.referenceFareVnd).toBeGreaterThanOrEqual(bikePlain.referenceFareVnd + 5000);
    expect(multi.body.data.stopCount).toBe(1);
    const car = multi.body.data.options.find((o: { multiStopService: string }) => o.multiStopService === 'CAR');
    if (car) {
      expect(car.available).toBe(false);
      expect(car.unavailableReason).toBe('RIDE_STOPS_DISABLED');
    }
  });

  it('validates stops: lat/lng range, max per service, flag off', async () => {
    const customer = await login();
    const bad = await postRide(customer.token, 'multistop-bad', 60_000, [{ lat: 123, lng: 106, label: 'x' }]);
    expect(bad.status).toBe(400);
    const tooMany = await postRide(customer.token, 'multistop-many', 60_000, [stopA, stopB, stopA]);
    expect(tooMany.status).toBe(400);
    expect(tooMany.body.errorCode).toBe('RIDE_TOO_MANY_STOPS');
    const car = await postRide(customer.token, 'multistop-car', 60_000, [stopA], 'CAR_4');
    expect(car.status).toBe(400);
    expect(JSON.stringify(car.body)).toMatch(/RIDE_STOPS_DISABLED|RIDE_VEHICLE_CLASS/);
  });

  it('single-destination booking is unchanged (no stops in the view)', async () => {
    const customer = await login();
    const created = await postRide(customer.token, 'multistop-plain', 60_000).expect(200);
    expect(created.body.data.stops).toEqual([]);
    expect(created.body.data.routeVersion).toBe(0);
    expect(created.body.data.waitFeeVnd).toBe(0);
    await post(customer.token, `/v1/rides/${created.body.data.id}/cancel`).expect(200);
  });

  it('editing stops before acceptance re-quotes, drops pending offers and needs the new version', async () => {
    const customer = await login();
    const d = await driver();
    const created = await postRide(customer.token, 'multistop-edit', 60_000, [stopA]).expect(200);
    const rideId = created.body.data.id as string;
    expect(created.body.data.stops).toHaveLength(1);
    const open = await get(d.token, '/v1/rides/open').expect(200);
    const listed = open.body.data.find((r: { id: string }) => r.id === rideId);
    expect(listed.stops).toHaveLength(1);
    expect(listed.routeVersion).toBe(0);
    // The realtime/push request payload carries the stops too (was a TypeError → no fan-out).
    const audience = await app.get(RideService).requestAudience(rideId);
    expect(audience?.ride.stops).toHaveLength(1);
    expect(audience?.ride.routeVersion).toBe(0);

    await offer(d.token, rideId, 60_000).expect(200);
    const edited = await http()
      .put(`/v1/rides/${rideId}/stops`)
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ stops: [stopA, stopB], routeVersion: 0 })
      .expect(200);
    expect(edited.body.data.routeVersion).toBe(1);
    expect(edited.body.data.stops.map((s: { label: string }) => s.label)).toEqual(['Stop A', 'Stop B']);
    expect(edited.body.data.referenceFareVnd).toBeGreaterThan(created.body.data.referenceFareVnd);
    expect(edited.body.data.offers.every((o: { status: string }) => o.status !== 'PENDING')).toBe(true);

    const stale = await http()
      .put(`/v1/rides/${rideId}/stops`)
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ stops: [], routeVersion: 0 });
    expect(stale.status).toBe(409);
    const staleOffer = await http()
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${d.token}`)
      .send({ amountVnd: 60_000, routeVersion: 0 });
    expect(staleOffer.status).toBe(409);
    await http()
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${d.token}`)
      .send({ amountVnd: 60_000, routeVersion: 1 })
      .expect(200);
    await post(customer.token, `/v1/rides/${rideId}/cancel`).expect(200);
  });

  it('full trip: stops locked after acceptance, ordered arrive/depart, wait fee in the cash due', async () => {
    const customer = await login();
    const d = await driver();
    const created = await postRide(customer.token, 'multistop-trip', 60_000, [stopA, stopB]).expect(200);
    const rideId = created.body.data.id as string;
    const offered = await offer(d.token, rideId, 60_000).expect(200);
    await http()
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'multistop-trip-sel')
      .send({ offerId: offered.body.data.offers[0].id })
      .expect(200);
    const locked = await http()
      .put(`/v1/rides/${rideId}/stops`)
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ stops: [] });
    expect(locked.status).toBe(409);
    expect(JSON.stringify(locked.body)).toContain('RIDE_STOPS_LOCKED');

    await post(d.token, `/v1/rides/${rideId}/en-route`).expect(200);
    await post(d.token, `/v1/rides/${rideId}/arrived`).expect(200);
    const code = (await get(customer.token, `/v1/rides/${rideId}`).expect(200)).body.data.pickupCode;
    const started = await post(d.token, `/v1/rides/${rideId}/start`, { pickupCode: code }).expect(200);
    expect(started.body.data.currentStopSeq).toBe(1);

    expect((await post(d.token, `/v1/rides/${rideId}/stops/2/arrive`)).status).toBe(409);
    expect((await post(d.token, `/v1/rides/${rideId}/complete`)).status).toBe(409);
    await post(d.token, `/v1/rides/${rideId}/stops/1/arrive`).expect(200);
    clock.advanceSeconds(8 * 60); // 3 billable minutes
    const left = await post(d.token, `/v1/rides/${rideId}/stops/1/depart`).expect(200);
    expect(left.body.data.currentStopSeq).toBe(2);
    await post(d.token, `/v1/rides/${rideId}/stops/2/arrive`).expect(200);
    await post(d.token, `/v1/rides/${rideId}/stops/2/depart`).expect(200);
    const done = await post(d.token, `/v1/rides/${rideId}/complete`).expect(200);
    expect(done.body.data.status).toBe('COMPLETED');
    expect(done.body.data.waitFeeVnd).toBe(3000);
    expect(done.body.data.cashDueVnd).toBe(60_000 + 3000);
    expect(done.body.data.stops.every((s: { departedAt: string | null }) => s.departedAt)).toBe(true);
    const history = await get(customer.token, `/v1/rides/${rideId}`).expect(200);
    expect(history.body.data.stops).toHaveLength(2);
  });
});
