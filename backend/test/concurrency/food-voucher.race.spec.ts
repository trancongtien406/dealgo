/**
 * Concurrent voucher redemption on food checkout against Postgres.
 * Skips when DATABASE_URL is unset (default unit suite uses memory repos).
 */
import { uniqueTestPhone } from './test-phone.js';
import { releaseVoucherInTx } from '../../src/modules/promotion/promotion-redemption.js';
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
import { MockSmsSender } from '../../src/integrations/sms/sms-sender.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { FoodModule } from '../../src/modules/food-order/food.module.js';
import { CatalogModule } from '../../src/modules/catalog/catalog.module.js';
import { PromotionModule } from '../../src/modules/promotion/promotion.module.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

const dropoff = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };

describePg('food voucher race (postgres)', () => {
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
              FOOD_MIN_DELIVERY_VND: '5000',
              FOOD_MAX_DELIVERY_VND: '100000',
              MAX_CONCURRENT_JOBS_PER_DRIVER: '2',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PrismaModule,
        FoodModule,
        CatalogModule,
        PromotionModule,
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
  });

  afterAll(async () => {
    await app.close();
  });

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

  async function setupStore(): Promise<{ storeId: string; itemId: string; merchantToken: string }> {
    const merchant = await login();
    await ensureGrant(app.get(IDENTITY_REPOSITORY), merchant.userId, 'MERCHANT');
    await request(app.getHttpServer())
      .get('/v1/food/merchant/catalog')
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    const item = await request(app.getHttpServer())
      .post('/v1/food/merchant/items')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ name: `Voucher Bun ${Date.now()}`, priceVnd: 60_000 })
      .expect(200);
    const catalog = await request(app.getHttpServer())
      .get('/v1/food/merchant/catalog')
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    return {
      storeId: catalog.body.data.id as string,
      itemId: item.body.data.id as string,
      merchantToken: merchant.token,
    };
  }

  async function createPromotion(code: string, usageLimit: number, userLimit: number) {
    const db = prisma.db()!;
    const now = Date.now();
    return db.promotion.create({
      data: {
        code,
        name: code,
        description: 'race test',
        serviceType: 'FOOD',
        discountType: 'FIXED_AMOUNT',
        discountValue: 10_000,
        totalBudget: 1_000_000,
        usageLimit,
        userLimit,
        startDate: new Date(now - 60_000),
        endDate: new Date(now + 3_600_000),
      },
    });
  }

  function place(token: string, key: string, store: { storeId: string; itemId: string }, voucherCode: string) {
    return request(app.getHttpServer())
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', key)
      .send({ storeId: store.storeId, dropoff, items: [{ itemId: store.itemId, quantity: 1 }], voucherCode });
  }

  it('lets only one of two racing checkouts consume a single-use voucher', async () => {
    const store = await setupStore();
    const code = `RACE${String(Date.now()).slice(-8)}`;
    const promo = await createPromotion(code, 1, 5);
    const [a, b] = [await login(), await login()];
    const results = await Promise.all([
      place(a.token, `va-${code}`, store, code),
      place(b.token, `vb-${code}`, store, code),
    ]);
    const statuses = results.map((r) => r.status).sort((x, y) => x - y);
    expect(statuses).toEqual([200, 422]);
    const winner = results.find((r) => r.status === 200)!;
    const loser = results.find((r) => r.status === 422)!;
    expect(winner.body.data.discountVnd).toBe(10_000);
    expect(winner.body.data.voucherCode).toBe(code);
    expect(winner.body.data.totalVnd).toBe(
      winner.body.data.subtotalVnd + winner.body.data.deliveryFareVnd - 10_000,
    );
    expect(loser.body.errorCode).toBe('VOUCHER_USAGE_EXHAUSTED');
    const db = prisma.db()!;
    const after = await db.promotion.findUniqueOrThrow({ where: { id: promo.id } });
    expect(after.usedCount).toBe(1);
    expect(after.usedBudget).toBe(10_000);
    expect(await db.promotionRedemption.count({ where: { promotionId: promo.id } })).toBe(1);
    // The rejected checkout must not leave an order behind.
    const loserUser = loser === results[0] ? a : b;
    expect(await db.foodOrder.count({ where: { customerId: loserUser.userId } })).toBe(0);
  });

  it('enforces userLimit and gives the use back when the order is cancelled', async () => {
    const store = await setupStore();
    const code = `ULIM${String(Date.now()).slice(-8)}`;
    const promo = await createPromotion(code, 10, 1);
    const customer = await login();
    const first = await place(customer.token, `u1-${code}`, store, code).expect(200);
    const quote = () =>
      request(app.getHttpServer())
        .post('/v1/promotions/validate')
        .set('Authorization', `Bearer ${customer.token}`)
        .send({ voucherCode: code, serviceType: 'FOOD', orderAmount: 60_000 })
        .expect(200);
    const limited = await quote();
    expect(limited.body.data.valid).toBe(false);
    expect(limited.body.data.rejectCode).toBe('VOUCHER_USER_LIMIT');

    const cancel = () =>
      request(app.getHttpServer())
        .post(`/v1/food/orders/${first.body.data.id}/cancel`)
        .set('Authorization', `Bearer ${customer.token}`);
    await cancel().expect(200);
    const db = prisma.db()!;
    let after = await db.promotion.findUniqueOrThrow({ where: { id: promo.id } });
    expect(after.usedCount).toBe(0);
    expect(after.usedBudget).toBe(0);
    const redemption = await db.promotionRedemption.findFirstOrThrow({
      where: { promotionId: promo.id },
    });
    expect(redemption.releasedAt).not.toBeNull();
    // Cancelling again is rejected and must not give the use back twice.
    expect((await cancel()).status).toBeGreaterThanOrEqual(400);
    await db.$transaction(async (tx) => {
      expect(
        await releaseVoucherInTx(tx, { entityType: 'FOOD_ORDER', entityId: first.body.data.id }),
      ).toBe(false);
    });
    after = await db.promotion.findUniqueOrThrow({ where: { id: promo.id } });
    expect(after.usedCount).toBe(0);

    // The released use counts no more toward userLimit.
    expect((await quote()).body.data.valid).toBe(true);
    const third = await place(customer.token, `u3-${code}`, store, code).expect(200);
    expect(third.body.data.discountVnd).toBe(10_000);
  });

  it('gives the use back exactly once when two fail calls race', async () => {
    const store = await setupStore();
    const code = `FAIL${String(Date.now()).slice(-8)}`;
    const promo = await createPromotion(code, 10, 1);
    const customer = await login();
    const driver = await login();
    await ensureGrant(app.get(IDENTITY_REPOSITORY), driver.userId, 'DRIVER');
    const placed = await place(customer.token, `f1-${code}`, store, code).expect(200);
    const orderId = placed.body.data.id as string;
    const call = (token: string, action: string) =>
      request(app.getHttpServer())
        .post(`/v1/food/orders/${orderId}/${action}`)
        .set('Authorization', `Bearer ${token}`);
    await call(store.merchantToken, 'accept').expect(200);
    await call(store.merchantToken, 'ready').expect(200);
    await call(driver.token, 'claim').expect(200);
    await call(driver.token, 'pickup').expect(200);
    const results = await Promise.all([call(driver.token, 'fail'), call(driver.token, 'fail')]);
    expect(results.map((r) => r.status).sort((a, b) => a - b)).toEqual([200, 409]);
    const db = prisma.db()!;
    const after = await db.promotion.findUniqueOrThrow({ where: { id: promo.id } });
    expect(after.usedCount).toBe(0);
    expect(after.usedBudget).toBe(0);
    const redemption = await db.promotionRedemption.findFirstOrThrow({
      where: { promotionId: promo.id },
    });
    expect(redemption.releasedAt).not.toBeNull();
  });

  it('same-key double submits always replay, never 409/422 (flake regression)', async () => {
    const store = await setupStore();
    for (let round = 0; round < 8; round += 1) {
      const code = `RACE${String(Date.now()).slice(-6)}${round}`;
      const promo = await createPromotion(code, 10, 5);
      const customer = await login();
      const results = await Promise.all(
        [0, 1, 2].map(() => place(customer.token, `idem-race-${code}`, store, code)),
      );
      expect(results.map((r) => r.status)).toEqual([200, 200, 200]);
      expect(new Set(results.map((r) => r.body.data.id)).size).toBe(1);
      const after = await prisma.db()!.promotion.findUniqueOrThrow({ where: { id: promo.id } });
      expect(after.usedCount).toBe(1);
    }
  });

  it('replays an idempotent checkout without redeeming twice', async () => {
    const store = await setupStore();
    const code = `IDEM${String(Date.now()).slice(-8)}`;
    const promo = await createPromotion(code, 10, 5);
    const customer = await login();
    const [x, y] = await Promise.all([
      place(customer.token, `same-${code}`, store, code),
      place(customer.token, `same-${code}`, store, code),
    ]);
    expect(x.status).toBe(200);
    expect(y.status).toBe(200);
    expect(y.body.data.id).toBe(x.body.data.id);
    const after = await prisma.db()!.promotion.findUniqueOrThrow({ where: { id: promo.id } });
    expect(after.usedCount).toBe(1);
  });
});

async function ensureGrant(
  identity: {
    insertGrant: (
      userId: string,
      role: 'DRIVER' | 'MERCHANT',
      status: 'ACTIVE',
    ) => Promise<unknown>;
  },
  userId: string,
  role: 'DRIVER' | 'MERCHANT',
): Promise<void> {
  try {
    await identity.insertGrant(userId, role, 'ACTIVE');
  } catch (error) {
    if (!(error instanceof UniqueConflictError)) {
      throw error;
    }
  }
}
