import { seedVehicleClassOnDriverGrant } from '../../support/driver-class-fixture.js';
/**
 * DEC-PROD-024 ride vouchers over HTTP (memory repositories): reserve on offer selection,
 * release on cancel/reassign, cash = fare - discount, DealGo-funded share owed to the driver.
 */
import { PLATFORM_SETTINGS_REPOSITORY } from '../../../src/platform/settings/platform-settings.constants.js';
import { bidBandOffSettings } from '../../support/settings-fixture.js';
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
import { IDENTITY_REPOSITORY, SMS_SENDER } from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { LEDGER_REPOSITORY } from '../../../src/modules/ledger/ledger.constants.js';
import { MemoryLedgerRepository } from '../../../src/modules/ledger/ledger.repository.js';
import { PROMOTION_REPOSITORY } from '../../../src/modules/promotion/promotion.constants.js';
import { MemoryPromotionRepository } from '../../../src/modules/promotion/promotion.repository.js';
import type { PromotionCampaign } from '../../../src/modules/promotion/promotion.types.js';
import { RideModule } from '../../../src/modules/ride/ride.module.js';

const OPS_EMAIL = 'ops-voucher@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';
const pickup = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };
const dropoff = { lat: 16.06, lng: 108.22, label: 'Sơn Trà' };

function campaign(code: string, overrides: Partial<PromotionCampaign> = {}): PromotionCampaign {
  const now = Date.now();
  return {
    id: `promo-${code}`,
    code,
    name: code,
    description: 'ride voucher test',
    serviceType: 'RIDE',
    discountType: 'FIXED_AMOUNT',
    discountValue: 10_000,
    minOrderAmount: 0,
    totalBudget: 1_000_000,
    usedBudget: 0,
    usageLimit: 100,
    usedCount: 0,
    userLimit: 5,
    targetAudience: 'ALL',
    status: 'ACTIVE',
    startDate: new Date(now - 60_000).toISOString(),
    endDate: new Date(now + 3_600_000).toISOString(),
    sponsor: 'PLATFORM',
    createdAt: new Date(now).toISOString(),
    updatedAt: new Date(now).toISOString(),
    ...overrides,
  };
}

describe('ride vouchers http (DEC-PROD-024)', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let sms: MockSmsSender;
  let promotions: MemoryPromotionRepository;
  let ledger: MemoryLedgerRepository;
  let serial = 500;

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    sms = new MockSmsSender('test');
    ledger = new MemoryLedgerRepository();
    promotions = new MemoryPromotionRepository([
      campaign('RIDE10K'),
      campaign('RIDEONCE', { userLimit: 1 }),
      campaign('RIDEFREE', { discountValue: 90_000 }),
      campaign('FOODONLY', { serviceType: 'FOOD' }),
      campaign('SHAREDALL', { serviceType: 'ALL', sponsor: 'SHARED' }),
      campaign('SHIPFREE', { serviceType: 'ALL', discountType: 'DELIVERY_DISCOUNT' }),
    ]);
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              JWT_ACCESS_SECRET: 'test-access-secret',
              SMS_PROVIDER: 'mock',
              RIDE_MIN_FARE_VND: '10000',
              RIDE_MAX_FARE_VND: '500000',
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
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .overrideProvider(PROMOTION_REPOSITORY)
      .useValue(promotions)
      .overrideProvider(LEDGER_REPOSITORY)
      .useValue(ledger)
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(await bidBandOffSettings())
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    seedVehicleClassOnDriverGrant(app, identity);
    await app.get(OpsAuthService).ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');
  });

  afterAll(async () => {
    await app.close();
  });

  it('reserves the voucher with the selection and collects fare minus discount', async () => {
    const { customer, driver, rideId, offerId } = await negotiate(40_000);
    const selected = await select(customer.token, rideId, offerId, 'sel-1', 'ride10k').expect(200);
    expect(selected.body.data).toMatchObject({
      status: 'ASSIGNED',
      agreedFareVnd: 40_000,
      discountVnd: 10_000,
      voucherCode: 'RIDE10K',
      cashDueVnd: 30_000,
    });
    expect(selected.body.data.voucherSponsor).toBeUndefined();
    expect((await promotions.findByCode('RIDE10K'))?.usedCount).toBe(1);

    // Replaying the same selection key never redeems twice.
    await select(customer.token, rideId, offerId, 'sel-1', 'RIDE10K').expect(200);
    expect((await promotions.findByCode('RIDE10K'))?.usedCount).toBe(1);

    const driverView = await get(driver.token, rideId);
    expect(driverView.body.data.cashDueVnd).toBe(30_000);

    await completeRide(customer, driver, rideId);
    const cod = await ledger.findByEntity('RIDE', rideId, 'COD_OBLIGATION_POSTED');
    expect(cod?.amountVnd).toBe(30_000);
    const funded = await ledger.findByEntity('RIDE', rideId, 'PROMOTION_DISCOUNT_FUNDED');
    expect(funded?.amountVnd).toBe(10_000);
    expect(funded?.entries.map((e) => [e.accountCode, e.direction])).toEqual(
      expect.arrayContaining([
        ['sandbox.promo.discount_expense', 'DEBIT'],
        ['sandbox.promo.driver_payable', 'CREDIT'],
      ]),
    );
    // Completion keeps the release a no-op: the use stays consumed.
    expect((await promotions.findByCode('RIDE10K'))?.usedCount).toBe(1);
  });

  it('gives the use back when the customer cancels', async () => {
    const before = (await promotions.findByCode('RIDEONCE'))!.usedCount;
    const { customer, rideId, offerId } = await negotiate(30_000);
    await select(customer.token, rideId, offerId, 'sel-c', 'RIDEONCE').expect(200);
    expect((await promotions.findByCode('RIDEONCE'))?.usedCount).toBe(before + 1);
    await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/cancel`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect((await promotions.findByCode('RIDEONCE'))?.usedCount).toBe(before);
    expect(await promotions.release({ entityType: 'RIDE', entityId: rideId })).toBe(false);

    // userLimit 1 is free again for the next ride.
    const next = await negotiate(30_000, customer);
    const again = await select(customer.token, next.rideId, next.offerId, 'sel-c2', 'RIDEONCE');
    expect(again.status).toBe(200);
    expect(again.body.data.discountVnd).toBe(10_000);
  });

  it('releases on ops reassign and lets the next selection apply a voucher again', async () => {
    const { customer, rideId, offerId } = await negotiate(30_000);
    await select(customer.token, rideId, offerId, 'sel-r', 'RIDE10K').expect(200);
    const used = (await promotions.findByCode('RIDE10K'))!.usedCount;
    const ops = await opsToken();
    const reassigned = await request(app.getHttpServer())
      .post(`/v1/ops/rides/${rideId}/reassign`)
      .set('Authorization', `Bearer ${ops}`)
      .send({ reason: 'TEST_ONLY driver unreachable' })
      .expect(200);
    expect(reassigned.body.data).toMatchObject({ discountVnd: 0, voucherCode: null });
    expect((await promotions.findByCode('RIDE10K'))?.usedCount).toBe(used - 1);

    const driver2 = await driverLogin();
    const offer2 = await offer(driver2.token, rideId, 35_000);
    const reselected = await select(customer.token, rideId, offer2, 'sel-r2', 'RIDE10K').expect(200);
    expect(reselected.body.data).toMatchObject({ discountVnd: 10_000, cashDueVnd: 25_000 });
    expect((await promotions.findByCode('RIDE10K'))?.usedCount).toBe(used);
  });

  it('rejects a voucher without assigning, and the customer can select without it', async () => {
    for (const code of ['FOODONLY', 'SHAREDALL', 'SHIPFREE', 'NOPE']) {
      const { customer, rideId, offerId } = await negotiate(30_000);
      const rejected = await select(customer.token, rideId, offerId, `sel-x-${code}`, code);
      expect(rejected.status).toBe(422);
      expect(rejected.body.errorCode).toBe(
        code === 'NOPE' ? 'VOUCHER_NOT_FOUND' : 'VOUCHER_WRONG_SERVICE',
      );
      expect((await get(customer.token, rideId)).body.data.status).toBe('NEGOTIATING');
      const plain = await select(customer.token, rideId, offerId, `sel-y-${code}`).expect(200);
      expect(plain.body.data).toMatchObject({ discountVnd: 0, cashDueVnd: 30_000 });
    }
  });

  it('completes a fully discounted ride without a cash journal', async () => {
    const { customer, driver, rideId, offerId } = await negotiate(40_000);
    const selected = await select(customer.token, rideId, offerId, 'sel-f', 'RIDEFREE').expect(200);
    expect(selected.body.data).toMatchObject({ discountVnd: 40_000, cashDueVnd: 0 });
    await completeRide(customer, driver, rideId);
    expect(await ledger.findByEntity('RIDE', rideId, 'COD_OBLIGATION_POSTED')).toBeNull();
    expect((await ledger.findByEntity('RIDE', rideId, 'PROMOTION_DISCOUNT_FUNDED'))?.amountVnd).toBe(
      40_000,
    );
  });

  async function negotiate(fare: number, existing?: { token: string; userId: string }) {
    const customer = existing ?? (await login());
    const driver = await driverLogin();
    const created = await request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `create-${serial++}`)
      .send({ pickup, dropoff, offeredFareVnd: 30_000, vehicleClassCode: 'MOTORBIKE'});
    expect(created.status).toBe(200);
    const rideId = created.body.data.id as string;
    const offerId = await offer(driver.token, rideId, fare);
    return { customer, driver, rideId, offerId };
  }

  async function offer(token: string, rideId: string, amountVnd: number): Promise<string> {
    const res = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${token}`)
      .send({ amountVnd })
      .expect(200);
    const offers = res.body.data.offers as Array<{ id: string; status: string }>;
    return offers.filter((o) => o.status === 'PENDING').at(-1)!.id;
  }

  function select(token: string, rideId: string, offerId: string, key: string, voucherCode?: string) {
    return request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `idem-voucher-${key}`)
      .send(voucherCode ? { offerId, voucherCode } : { offerId });
  }

  function get(token: string, rideId: string) {
    return request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
  }

  async function completeRide(
    customer: { token: string },
    driver: { token: string },
    rideId: string,
  ): Promise<void> {
    const step = (action: string, body?: object) =>
      request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/${action}`)
        .set('Authorization', `Bearer ${driver.token}`)
        .send(body ?? {})
        .expect(200);
    await step('en-route');
    await step('arrived');
    const code = (await get(customer.token, rideId)).body.data.pickupCode as string;
    await step('start', { pickupCode: code });
    const done = await step('complete');
    expect(done.body.data.status).toBe('COMPLETED');
  }

  async function opsToken(): Promise<string> {
    const ops = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    return ops.body.data.accessToken as string;
  }

  async function driverLogin() {
    const driver = await login();
    await identity.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    return driver;
  }

  async function login(): Promise<{ token: string; userId: string }> {
    serial += 1;
    const phone = `093${String(serial).padStart(7, '0')}`;
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
});
