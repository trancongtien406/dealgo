/**
 * DEC-PROD-024 ride vouchers against Postgres: the redemption commits with the offer
 * selection, races cannot over-spend a campaign, cancel/reassign release, and completion
 * books cash = fare - discount plus the DealGo-funded share owed to the driver.
 * Skips when DATABASE_URL is unset.
 */
import { randomUUID } from 'node:crypto';
import { uniqueTestPhone } from './test-phone.js';
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
import { UniqueConflictError } from '../../src/modules/identity/identity.repository.js';
import { OpsAuthService } from '../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../src/integrations/sms/sms-sender.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PARTNER_REPOSITORY } from '../../src/modules/partner/partner.constants.js';
import type { PartnerRepository } from '../../src/modules/partner/partner.repository.js';
import { RideModule } from '../../src/modules/ride/ride.module.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

const pickup = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };
// Fare floor (80 % of reference): keep the trip short so the fixed 30k bid clears the floor
// whatever per-km price the local DB vehicle class carries.
const dropoff = { lat: 16.05, lng: 108.208, label: 'Hải Châu 2' };
const OPS_EMAIL = `ops-ride-voucher-${Date.now()}@dealgo.test`;
const OPS_PASSWORD = 'correct-horse-battery';

describePg('ride voucher (postgres)', () => {
  let app: INestApplication;
  let sms: MockSmsSender;
  let prisma: PrismaService;

  beforeAll(async () => {
    sms = new MockSmsSender('test');
    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              DATABASE_URL: process.env.DATABASE_URL,
              JWT_ACCESS_SECRET: 'test-access-secret',
              SMS_PROVIDER: 'mock',
              PUSH_PROVIDER: 'mock',
              PARTNER_ELIGIBILITY_BYPASS: 'true',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
              RIDE_MIN_FARE_VND: '10000',
              RIDE_MAX_FARE_VND: '500000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PrismaModule,
        RideModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    prisma = app.get(PrismaService);
    if (!prisma.db()) {
      throw new Error('DATABASE_URL did not open a Prisma client');
    }
    await app.get(OpsAuthService).ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');
  });

  afterAll(async () => {
    await app.close();
  });

  it('lets only one of two customers take the last use', async () => {
    const code = await createPromotion({ usageLimit: 1 });
    const a = await negotiate(40_000);
    const b = await negotiate(40_000);
    const results = await Promise.all([
      select(a.customer.token, a.rideId, a.offerId, code),
      select(b.customer.token, b.rideId, b.offerId, code),
    ]);
    const statuses = results.map((r) => r.status).sort((a, b) => a - b);
    expect(statuses).toEqual([200, 422]);
    expect(results.find((r) => r.status === 422)?.body.errorCode).toBe('VOUCHER_USAGE_EXHAUSTED');
    const promo = await prisma.db()!.promotion.findUnique({ where: { code } });
    expect(promo?.usedCount).toBe(1);
    expect(promo?.usedBudget).toBe(10_000);
    // The loser's ride rolled back to negotiation with no voucher snapshot.
    const loser = results[0].status === 422 ? a : b;
    const row = await prisma.db()!.ride.findUnique({ where: { id: loser.rideId } });
    expect(row).toMatchObject({ status: 'NEGOTIATING', discountVnd: 0, voucherCode: null });
  });

  it('redeems once when two selections of the same ride race', async () => {
    const code = await createPromotion({ usageLimit: 10 });
    const { customer, rideId, offerId } = await negotiate(40_000);
    const results = await Promise.all([
      select(customer.token, rideId, offerId, code),
      select(customer.token, rideId, offerId, code),
    ]);
    expect(results.filter((r) => r.status === 200).length).toBeGreaterThanOrEqual(1);
    const promo = await prisma.db()!.promotion.findUnique({ where: { code } });
    expect(promo?.usedCount).toBe(1);
    expect(
      await prisma.db()!.promotionRedemption.count({ where: { entityType: 'RIDE', entityId: rideId } }),
    ).toBe(1);
  });

  it('releases on cancel and revives the row after ops reassign', async () => {
    const code = await createPromotion({ usageLimit: 10, userLimit: 1 });
    const first = await negotiate(30_000);
    await select(first.customer.token, first.rideId, first.offerId, code).expect(200);
    await request(app.getHttpServer())
      .post(`/v1/rides/${first.rideId}/cancel`)
      .set('Authorization', `Bearer ${first.customer.token}`)
      .expect(200);
    const db = prisma.db()!;
    expect((await db.promotion.findUnique({ where: { code } }))?.usedCount).toBe(0);
    const released = await db.promotionRedemption.findUnique({
      where: { entityType_entityId: { entityType: 'RIDE', entityId: first.rideId } },
    });
    expect(released?.releasedAt).not.toBeNull();

    const second = await negotiate(30_000);
    await select(second.customer.token, second.rideId, second.offerId, code).expect(200);
    const ops = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/ops/rides/${second.rideId}/reassign`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .send({ reason: 'TEST_ONLY driver unreachable' })
      .expect(200);
    expect((await db.ride.findUnique({ where: { id: second.rideId } }))?.voucherCode).toBeNull();
    expect((await db.promotion.findUnique({ where: { code } }))?.usedCount).toBe(0);

    const driver2 = await driverLogin();
    const offer2 = await offer(driver2.token, second.rideId, 35_000);
    const again = await select(second.customer.token, second.rideId, offer2, code).expect(200);
    expect(again.body.data).toMatchObject({ discountVnd: 10_000, cashDueVnd: 25_000 });
    const rows = await db.promotionRedemption.findMany({
      where: { entityType: 'RIDE', entityId: second.rideId },
    });
    expect(rows).toHaveLength(1);
    expect(rows[0].releasedAt).toBeNull();
    expect((await db.promotion.findUnique({ where: { code } }))?.usedCount).toBe(1);
  });

  it('books cash = fare - discount and the funded share owed to the driver', async () => {
    const code = await createPromotion({ usageLimit: 10 });
    const { customer, driver, rideId, offerId } = await negotiate(45_000);
    await select(customer.token, rideId, offerId, code).expect(200);
    const step = (action: string, body?: object) =>
      request(app.getHttpServer())
        .post(`/v1/rides/${rideId}/${action}`)
        .set('Authorization', `Bearer ${driver.token}`)
        .send(body ?? {})
        .expect(200);
    await step('en-route');
    await step('arrived');
    const view = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    await step('start', { pickupCode: view.body.data.pickupCode });
    const done = await step('complete');
    expect(done.body.data).toMatchObject({ status: 'COMPLETED', cashDueVnd: 35_000 });

    const db = prisma.db()!;
    const journals = await db.ledgerJournal.findMany({
      where: { entityType: 'RIDE', entityId: rideId },
      include: { entries: { include: { account: true } } },
    });
    const byEvent = Object.fromEntries(journals.map((j) => [j.event, j]));
    expect(byEvent.COD_OBLIGATION_POSTED?.amountVnd).toBe(35_000);
    expect(byEvent.PROMOTION_DISCOUNT_FUNDED?.amountVnd).toBe(10_000);
    const credit = byEvent.PROMOTION_DISCOUNT_FUNDED?.entries.find((e) => e.direction === 'CREDIT');
    expect(credit?.account.code).toBe('sandbox.promo.driver_payable');
    const earning = await db.jobEarning.findFirst({ where: { entityType: 'RIDE', entityId: rideId } });
    expect(earning?.fareVnd).toBe(45_000);
  });

  async function createPromotion(limits: { usageLimit: number; userLimit?: number }): Promise<string> {
    const code = `RV${randomUUID().slice(0, 8).toUpperCase()}`;
    const now = Date.now();
    await prisma.db()!.promotion.create({
      data: {
        code,
        name: code,
        description: 'ride voucher race test',
        serviceType: 'RIDE',
        discountType: 'FIXED_AMOUNT',
        discountValue: 10_000,
        totalBudget: 1_000_000,
        usageLimit: limits.usageLimit,
        userLimit: limits.userLimit ?? 5,
        startDate: new Date(now - 60_000),
        endDate: new Date(now + 3_600_000),
      },
    });
    return code;
  }

  async function negotiate(fare: number) {
    const customer = await login();
    const driver = await driverLogin();
    const created = await request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `idem-rv-create-${randomUUID()}`)
      .send({ pickup, dropoff, offeredFareVnd: 30_000, vehicleClassCode: 'MOTORBIKE'});
    if (created.status !== 200) throw new Error(`create ride ${created.status}: ${JSON.stringify(created.body)}`);
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

  function select(token: string, rideId: string, offerId: string, voucherCode: string) {
    return request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `idem-rv-select-${randomUUID()}`)
      .send({ offerId, voucherCode });
  }

  async function driverLogin() {
    const driver = await login();
    try {
      await app.get(IDENTITY_REPOSITORY).insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    } catch (error) {
      if (!(error instanceof UniqueConflictError)) {
        throw error;
      }
    }
    // DG-DEC-VEH-001: offers fail closed without a DRIVER application carrying the class.
    const partners = app.get<PartnerRepository>(PARTNER_REPOSITORY);
    if (!(await partners.findByUserAndRole(driver.userId, 'DRIVER'))) {
      await partners.upsertSubmit({
        id: randomUUID(),
        userId: driver.userId,
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE' },
        documents: [],
        now: new Date(),
      });
    }
    return driver;
  }

  async function login(): Promise<{ token: string; userId: string }> {
    const phone = uniqueTestPhone();
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
