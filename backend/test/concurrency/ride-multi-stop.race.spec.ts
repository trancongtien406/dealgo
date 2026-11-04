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
import { PLATFORM_SETTINGS_REPOSITORY } from '../../src/platform/settings/platform-settings.constants.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { settingsWith } from '../support/settings-fixture.js';

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
const stopA = { lat: 10.79, lng: 106.68, label: 'Stop A' };
const stopB = { lat: 10.80, lng: 106.66, label: 'Stop B' };

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
describePg('ride multi-stop races (postgres)', () => {
  let app: INestApplication;
  let repository: { insertGrant: (u: string, r: 'DRIVER', s: 'ACTIVE') => Promise<unknown> };
  let sms: MockSmsSender;
  let clock: ManualClock;
  let prisma: PrismaService;
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
      // Flags on for this suite only (the dev DB keeps its seeded OFF values).
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(
        await settingsWith({
          RIDE_MULTI_STOP_BIKE_ENABLED: true,
          RIDE_MAX_STOPS_BIKE: 2,
          RIDE_STOP_FEE_BIKE_VND: 5000,
          RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE: 0,
        }),
      )
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    repository = app.get(IDENTITY_REPOSITORY);
    prisma = app.get(PrismaService);
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
      .send({ ...at, stops: [stopA], offeredFareVnd, vehicleClassCode });
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


  function putStops(token: string, rideId: string, body: object) {
    return http().put(`/v1/rides/${rideId}/stops`).set('Authorization', `Bearer ${token}`).send(body);
  }

  it('select vs stop edit: exactly one wins and the stored route matches the winner', async () => {
    for (let round = 0; round < 6; round += 1) {
      const customer = await login();
      const d = await driver();
      const created = await postRide(customer.token, `race-${round}`, bid()).expect(200);
      const rideId = created.body.data.id as string;
      const offered = await offer(d.token, rideId, bid()).expect(200);
      const offerId = offered.body.data.offers[0].id as string;
      const [selected, edited] = await Promise.all([
        http()
          .post(`/v1/rides/${rideId}/selection`)
          .set('Authorization', `Bearer ${customer.token}`)
          .set('Idempotency-Key', `${RUN}-race-${round}-s`)
          .send({ offerId }),
        putStops(customer.token, rideId, { stops: [stopA, stopB], routeVersion: 0 }),
      ]);
      const wins = [selected.status, edited.status].filter((s) => s === 200).length;
      expect(wins).toBe(1);
      const ride = await prisma.db()!.ride.findUniqueOrThrow({ where: { id: rideId }, include: { stops: true, offers: true } });
      if (selected.status === 200) {
        expect(edited.status).toBe(409);
        expect(ride.status).toBe('ASSIGNED');
        expect(ride.routeVersion).toBe(0);
        expect(ride.stops).toHaveLength(1);
        await post(customer.token, `/v1/rides/${rideId}/cancel`);
      } else {
        expect(ride.status).toBe('NEGOTIATING');
        expect(ride.routeVersion).toBe(1);
        expect(ride.stopCount).toBe(2);
        expect(ride.stops.map((s) => s.seq).sort((x, y) => x - y)).toEqual([1, 2]);
        expect(ride.offers.find((o) => o.id === offerId)?.status).toBe('LOST');
        await post(customer.token, `/v1/rides/${rideId}/cancel`).expect(200);
      }
    }
  });

  it('two concurrent edits on the same version: one applies, the other gets RIDE_ROUTE_CHANGED', async () => {
    const customer = await login();
    const created = await postRide(customer.token, 'double-edit', bid()).expect(200);
    const rideId = created.body.data.id as string;
    const [a, b] = await Promise.all([
      putStops(customer.token, rideId, { stops: [stopB], routeVersion: 0 }),
      putStops(customer.token, rideId, { stops: [stopA, stopB], routeVersion: 0 }),
    ]);
    expect([a.status, b.status].sort((x, y) => x - y)).toEqual([200, 409]);
    const loser = a.status === 409 ? a : b;
    expect(loser.body.errorCode).toBe('RIDE_ROUTE_CHANGED');
    const ride = await prisma.db()!.ride.findUniqueOrThrow({ where: { id: rideId }, include: { stops: true } });
    expect(ride.routeVersion).toBe(1);
    expect(ride.stops).toHaveLength(ride.stopCount);
    await post(customer.token, `/v1/rides/${rideId}/cancel`).expect(200);
  });

  it('stop events persist to ride_stops and write a deduped realtime outbox hint', async () => {
    const customer = await login();
    const d = await driver();
    const rideId = await assigned(customer, d, 'events');
    await post(d.token, `/v1/rides/${rideId}/en-route`).expect(200);
    await post(d.token, `/v1/rides/${rideId}/arrived`).expect(200);
    const code = (await get(customer.token, `/v1/rides/${rideId}`).expect(200)).body.data.pickupCode;
    await post(d.token, `/v1/rides/${rideId}/start`, { pickupCode: code }).expect(200);
    await Promise.all([
      post(d.token, `/v1/rides/${rideId}/stops/1/arrive`),
      post(d.token, `/v1/rides/${rideId}/stops/1/arrive`),
    ]);
    await post(d.token, `/v1/rides/${rideId}/stops/1/depart`).expect(200);
    const stops = await prisma.db()!.rideStop.findMany({ where: { rideId } });
    expect(stops).toHaveLength(1);
    expect(stops[0]!.arrivedAt).not.toBeNull();
    expect(stops[0]!.departedAt).not.toBeNull();
    const hints = await prisma.db()!.outboxMessage.findMany({
      where: { aggregateId: rideId, eventKey: { contains: ':stop-' } },
    });
    expect(hints.map((h) => h.eventKey.split(':').at(-1)).sort((x, y) => (x ?? '').localeCompare(y ?? ''))).toEqual(['stop-1-arrived', 'stop-1-departed']);
    await post(d.token, `/v1/rides/${rideId}/complete`).expect(200);
  });
});
