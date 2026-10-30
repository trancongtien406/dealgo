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
import { PlatformSettingsService } from '../../../src/platform/settings/platform-settings.service.js';
import { RideZoneTariffService } from '../../../src/modules/ride-vehicle/ride-zone-tariff.service.js';
import { RIDE_ZONE_TARIFF_REPOSITORY } from '../../../src/modules/ride-vehicle/ride-vehicle-class.constants.js';
import type { MemoryRideZoneTariffRepository } from '../../../src/modules/ride-vehicle/ride-zone-tariff.repository.js';
import { rideBidCeilingVnd } from '../../../src/modules/ride-vehicle/ride-vehicle-class.js';

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
describe('ride zone tariff + locked bid band http', () => {
  let app: INestApplication;
  let repository: MemoryIdentityRepository;
  let sms: MockSmsSender;
  let clock: ManualClock;
  let phoneSerial = 7000;
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
      .useValue(
        await settingsWith({
          RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE: 70,
          RIDE_BID_CEILING_PERCENT_OF_REFERENCE: 130,
          RIDE_COUNTER_MAX_PERCENT_OF_OFFER: 200,
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



  const OPS = '00000000-0000-4000-8000-0000000000aa';
  const tariffs = () => app.get(RideZoneTariffService);
  const settingsSvc = () => app.get(PlatformSettingsService);
  const auditRepo = () => app.get<MemoryRideZoneTariffRepository>(RIDE_ZONE_TARIFF_REPOSITORY);
  const bike = (quote: { body: { data: { options: Array<{ code: string }> } } }) =>
    quote.body.data.options.find((o) => o.code === 'MOTORBIKE') as unknown as {
      referenceFareVnd: number;
      minBidVnd: number;
      maxBidVnd: number;
      perKmVnd: number;
      tariff: { source: string; regionCode: string | null; version: number; perKmVnd: number; bidCeilingPercent: number };
    };

  afterEach(async () => {
    await tariffs().remove('HCM', 'MOTORBIKE', OPS).catch(() => undefined);
    await settingsSvc().patch('RIDE_BID_CEILING_PERCENT_OF_REFERENCE', '130', 'test reset', OPS);
  });

  it('quote uses the global default when the zone has no override and reports the tariff source', async () => {
    const customer = await login();
    const quote = bike(await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200));
    expect(quote.tariff).toMatchObject({ source: 'DEFAULT', regionCode: 'HCM', version: 0, bidCeilingPercent: 130 });
  });

  it('zone override (resolved server-side from pickup) replaces perKm/minFare; delete falls back', async () => {
    const customer = await login();
    const before = bike(await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200));
    await tariffs().upsert('hcm', 'motorbike', { perKmVnd: before.perKmVnd * 2, minFareVnd: 12_000, reason: 'test' }, OPS);
    const zoned = bike(await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200));
    expect(zoned.tariff).toMatchObject({ source: 'ZONE', regionCode: 'HCM', version: 1, perKmVnd: before.perKmVnd * 2 });
    expect(zoned.referenceFareVnd).toBeGreaterThan(before.referenceFareVnd);
    const audits = auditRepo().audits.filter((a) => a.action === 'RIDE_ZONE_TARIFF_UPSERT');
    expect(audits.at(-1)).toMatchObject({ actorUserId: OPS, changes: { perKmVnd: { from: null, to: before.perKmVnd * 2 } } });
    await tariffs().remove('HCM', 'MOTORBIKE', OPS, 'back to default');
    expect(auditRepo().audits.at(-1)?.action).toBe('RIDE_ZONE_TARIFF_DELETE');
    const after = bike(await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200));
    expect(after.tariff.source).toBe('DEFAULT');
    expect(after.referenceFareVnd).toBe(before.referenceFareVnd);
  });

  it('admin validation rejects bad overrides', async () => {
    await expect(tariffs().upsert('XX', 'MOTORBIKE', { perKmVnd: 5000, minFareVnd: 10_000 }, OPS)).rejects.toMatchObject({ status: 404 });
    await expect(tariffs().upsert('HCM', 'NOPE', { perKmVnd: 5000, minFareVnd: 10_000 }, OPS)).rejects.toMatchObject({ status: 404 });
    await expect(tariffs().upsert('HCM', 'MOTORBIKE', { perKmVnd: -1, minFareVnd: 10_000 }, OPS)).rejects.toMatchObject({ status: 400 });
    await expect(tariffs().upsert('HCM', 'MOTORBIKE', { perKmVnd: 5000, minFareVnd: 99_999_999 }, OPS)).rejects.toMatchObject({ status: 400 });
    await expect(tariffs().remove('HCM', 'MOTORBIKE', OPS)).rejects.toMatchObject({ status: 404 });
  });

  it('band edge: exactly -30% / +30% of reference accepted, one step outside rejected', async () => {
    const customer = await login();
    const quote = bike(await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200));
    const floor = rideBidFloorVnd(quote.referenceFareVnd, 70);
    const ceiling = rideBidCeilingVnd(quote.referenceFareVnd, 130);
    expect(quote.minBidVnd).toBe(Math.max(floor, quote.minBidVnd));
    expect(quote.maxBidVnd).toBe(ceiling);
    const low = await postRide(customer.token, 'edge-low-key', floor - 1000);
    expect(low.status).toBe(400);
    expect(low.body.error?.code ?? low.body.errorCode ?? JSON.stringify(low.body)).toContain('RIDE_FARE_OUT_OF_RANGE');
    const high = await postRide(customer.token, 'edge-high-key', ceiling + 1000);
    expect(high.status).toBe(400);
    await postRide(customer.token, 'edge-ceiling', ceiling).expect(200);
    const other = await login();
    await postRide(other.token, 'edge-floor', floor).expect(200);
  });

  it('a band or zone tariff change does not affect an open negotiation (locked snapshot)', async () => {
    const customer = await login();
    const d = await driver();
    const q = bike(await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200));
    const created = await postRide(customer.token, 'lock-create-1', q.referenceFareVnd);
    expect(created.status, JSON.stringify(created.body)).toBe(200);
    const rideId = created.body.data.id as string;
    const ref = created.body.data.referenceFareVnd as number;
    const lockedCeiling = rideBidCeilingVnd(ref, 130);
    // Admin widens the band and reprices the zone after booking.
    await settingsSvc().patch('RIDE_BID_CEILING_PERCENT_OF_REFERENCE', '200', 'test widen', OPS);
    await tariffs().upsert('HCM', 'MOTORBIKE', { perKmVnd: 20_000, minFareVnd: 30_000 }, OPS);
    const tooHigh = roundUpToFareStep(lockedCeiling + 1000);
    const rejected = await offer(d.token, rideId, tooHigh);
    expect(rejected.status).toBe(400);
    expect(JSON.stringify(rejected.body)).toContain('RIDE_COUNTER_OUT_OF_RANGE');
    const ok = await offer(d.token, rideId, roundDownToFareStep(lockedCeiling));
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    // The customer's raise is still checked against the locked +30%.
    const raise = await post(customer.token, `/v1/rides/${rideId}/fare`, { amountVnd: tooHigh });
    expect(raise.status).toBe(400);
    // A new quote sees the new values.
    const fresh = bike(await post(customer.token, '/v1/rides/quote', { pickup, dropoff }).expect(200));
    expect(fresh.tariff).toMatchObject({ source: 'ZONE', bidCeilingPercent: 200 });
  });
});
