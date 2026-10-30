import { seedDriverClass } from './driver-class.js';
/**
 * food dispatch against Postgres (Prisma repositories + migrated DRAFT settings rows):
 * early claim, driver release + driver_job_cancellations, merchant-accept /
 * unclaimed-READY timeouts and the cash plan + platform-funded voucher adjustment
 * (cash model). Mirrors test/integration/food-order/food-dispatch-lifecycle.http.spec.ts.
 * Skips when DATABASE_URL is unset.
 */
import { randomUUID } from 'node:crypto';
import { uniqueTestPhone } from './test-phone.js';
import { pinStore } from './store-pin.js';
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
import { FoodService } from '../../src/modules/food-order/food.service.js';
import { EarningsService } from '../../src/modules/earnings/earnings.service.js';
import { PlatformSettingsService } from '../../src/platform/settings/platform-settings.service.js';
import { PROMOTION_REPOSITORY } from '../../src/modules/promotion/promotion.constants.js';
import type { PromotionRepository } from '../../src/modules/promotion/promotion.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;
const RUN = `pgf-${Date.now()}-${randomUUID().slice(0, 6)}`;
const dropoff = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };

type Actor = { token: string; userId: string };

describePg('food dispatch (postgres)', () => {
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
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PrismaModule,
        FoodModule,
        CatalogModule,
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
    if (!prisma.db()) throw new Error('DATABASE_URL did not open a Prisma client');
  });

  afterAll(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());
  const settings = () => app.get(PlatformSettingsService);
  const post = (token: string, path: string, body: object = {}) =>
    http().post(path).set('Authorization', `Bearer ${token}`).send(body);
  const get = (token: string, path: string) => http().get(path).set('Authorization', `Bearer ${token}`);

  async function login(): Promise<Actor> {
    const created = await http().post('/v1/auth/phone/challenges').send({ phone: uniqueTestPhone() }).expect(200);
    const verified = await http()
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code: sms.sent.at(-1)?.code })
      .expect(200);
    return { token: verified.body.data.accessToken, userId: verified.body.data.user.id };
  }

  async function grant(userId: string, role: 'DRIVER' | 'MERCHANT') {
    try {
      await app.get(IDENTITY_REPOSITORY).insertGrant(userId, role, 'ACTIVE');
    } catch (error) {
      if (!(error instanceof UniqueConflictError)) throw error;
    }
  }

  async function onlineDriver(): Promise<Actor> {
    const d = await login();
    await grant(d.userId, 'DRIVER');
    await seedDriverClass(app, d.userId);
    await post(d.token, '/v1/me/presence', { online: true, lat: dropoff.lat + 0.002, lng: dropoff.lng + 0.002 }).expect(200);
    return d;
  }

  /** A fresh merchant with its own store + one item (no shared seed rows between runs). */
  async function merchantWithItem(tag: string): Promise<{ merchant: Actor; storeId: string; itemId: string }> {
    const merchant = await login();
    await grant(merchant.userId, 'MERCHANT');
    await get(merchant.token, '/v1/food/merchant/catalog').expect(200);
    const item = await post(merchant.token, '/v1/food/merchant/items', { name: `${tag} ${RUN}`, priceVnd: 45_000 }).expect(200);
    const catalog = await get(merchant.token, '/v1/food/merchant/catalog').expect(200);
    await pinStore(app, merchant.token);
    return { merchant, storeId: catalog.body.data.id, itemId: item.body.data.id };
  }

  async function placeOrder(customer: Actor, storeId: string, itemId: string, key: string, extra: object = {}) {
    const placed = await http()
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `${RUN}-${key}`)
      .send({ storeId, dropoff, deliveryFareVnd: 15_000, items: [{ itemId, quantity: 1 }], ...extra });
    if (placed.status !== 200) throw new Error(`place ${placed.status}: ${JSON.stringify(placed.body)}`);
    return placed.body.data as { id: string; subtotalVnd: number; totalVnd: number };
  }

  async function withSetting<T>(key: string, value: string, reset: string, run: () => Promise<T>): Promise<T> {
    // updatedByUserId is a FK to users: any real user id works as the audit actor in tests.
    const actor = (await login()).userId;
    await settings().patch(key as never, value, 'pg test', actor);
    try {
      return await run();
    } finally {
      await settings().patch(key as never, reset, 'pg test reset', actor);
    }
  }

  it('early claim while PREPARING (lead 15 min); ready → ASSIGNED; pickup only after ready', async () => {
    const customer = await login();
    const { merchant, storeId, itemId } = await merchantWithItem('Early');
    const d = await onlineDriver();
    const order = await placeOrder(customer, storeId, itemId, 'early');
    await post(merchant.token, `/v1/food/orders/${order.id}/accept`).expect(200);

    const notYet = await post(d.token, `/v1/food/orders/${order.id}/claim`);
    expect(notYet.status).toBe(409);
    expect(notYet.body.errorCode).toBe('FOOD_NOT_YET_CLAIMABLE');

    await withSetting('FOOD_EARLY_ASSIGN_LEAD_MINUTES', '15', '10', async () => {
      const listed = await get(d.token, '/v1/food/orders/ready').expect(200);
      const row = (listed.body.data as { id: string; status: string }[]).find((o) => o.id === order.id);
      expect(row?.status).toBe('PREPARING');
      const claimed = await post(d.token, `/v1/food/orders/${order.id}/claim`).expect(200);
      expect(claimed.body.data).toMatchObject({ status: 'PREPARING', assignedDriverId: d.userId });
    });
    await post(d.token, `/v1/food/orders/${order.id}/pickup`).expect(409);
    const ready = await post(merchant.token, `/v1/food/orders/${order.id}/ready`).expect(200);
    expect(ready.body.data).toMatchObject({ status: 'ASSIGNED', assignedDriverId: d.userId });
    await post(d.token, `/v1/food/orders/${order.id}/pickup`).expect(200);
  });

  it('release records driver_job_cancellations and returns the order to READY', async () => {
    const customer = await login();
    const { merchant, storeId, itemId } = await merchantWithItem('Release');
    const d = await onlineDriver();
    const other = await onlineDriver();
    const order = await placeOrder(customer, storeId, itemId, 'release');
    await post(merchant.token, `/v1/food/orders/${order.id}/accept`).expect(200);
    await post(merchant.token, `/v1/food/orders/${order.id}/ready`).expect(200);
    await post(d.token, `/v1/food/orders/${order.id}/claim`).expect(200);

    expect((await post(other.token, `/v1/food/orders/${order.id}/release`, { reasonCode: 'STORE_TOO_SLOW' })).status).toBe(403);
    expect((await post(d.token, `/v1/food/orders/${order.id}/fail`, { reasonCode: 'CUSTOMER_REFUSED' })).status).toBe(409);
    const released = await post(d.token, `/v1/food/orders/${order.id}/release`, { reasonCode: 'STORE_TOO_SLOW' }).expect(200);
    expect(released.body.data).toMatchObject({ status: 'READY', assignedDriverId: null });

    const rows = await prisma.db()!.driverJobCancellation.findMany({ where: { driverId: d.userId } });
    expect(rows).toEqual([
      expect.objectContaining({ reasonCode: 'STORE_TOO_SLOW', fromStatus: 'ASSIGNED' }),
    ]);

    await post(other.token, `/v1/food/orders/${order.id}/claim`).expect(200);
    await post(other.token, `/v1/food/orders/${order.id}/pickup`).expect(200);
    expect((await post(other.token, `/v1/food/orders/${order.id}/fail`, { reasonCode: 'CUSTOMER_REFUSED' }).expect(200)).body.data.status).toBe('FAILED');
  });

  it('merchant-accept and unclaimed-READY timeouts cancel as SYSTEM', async () => {
    const customer = await login();
    const readyCustomer = await login();
    const { merchant, storeId, itemId } = await merchantWithItem('Timeout');
    const placed = await placeOrder(customer, storeId, itemId, 'timeout-placed');
    const ready = await placeOrder(readyCustomer, storeId, itemId, 'timeout-ready');
    await post(merchant.token, `/v1/food/orders/${ready.id}/accept`).expect(200);
    await post(merchant.token, `/v1/food/orders/${ready.id}/ready`).expect(200);

    const food = app.get(FoodService);
    expect((await food.timeoutDue(new Date(Date.now() + 4 * 60_000))).orderIds).not.toContain(placed.id);
    const first = await food.timeoutDue(new Date(Date.now() + 6 * 60_000));
    expect(first.orderIds).toContain(placed.id);
    expect(first.orderIds).not.toContain(ready.id);
    expect((await food.timeoutDue(new Date(Date.now() + 31 * 60_000))).orderIds).toContain(ready.id);

    const placedView = await get(customer.token, `/v1/food/orders/${placed.id}`).expect(200);
    expect(placedView.body.data).toMatchObject({ status: 'CANCELLED', cancelledBy: 'SYSTEM' });
    expect(placedView.body.data.cancelReason).toMatchObject({ code: 'MERCHANT_TIMEOUT' });
    const readyView = await get(readyCustomer.token, `/v1/food/orders/${ready.id}`).expect(200);
    expect(readyView.body.data).toMatchObject({ status: 'CANCELLED', cancelledBy: 'SYSTEM' });
    expect(readyView.body.data.cancelReason).toMatchObject({ code: 'NO_DRIVER' });
  });

  it('cash model: cash plan for the assigned driver; platform voucher share credited on deliver', async () => {
    const code = `R18PG${Date.now().toString(36).toUpperCase()}`;
    const now = Date.now();
    await app.get<PromotionRepository>(PROMOTION_REPOSITORY).create({
      code,
      name: code,
      description: 'pg',
      serviceType: 'FOOD',
      discountType: 'FIXED_AMOUNT',
      discountValue: 10_000,
      minOrderAmount: 0,
      totalBudget: 1_000_000,
      usageLimit: 10,
      userLimit: 1,
      targetAudience: 'ALL',
      status: 'ACTIVE',
      startDate: new Date(now - 60_000),
      endDate: new Date(now + 3_600_000),
      sponsor: 'SHARED',
    } as never);
    await withSetting('VOUCHER_SHARED_PLATFORM_PERCENT', '30', '100', async () => {
      const customer = await login();
      const { merchant, storeId, itemId } = await merchantWithItem('Cash');
      const d = await onlineDriver();
      const order = await placeOrder(customer, storeId, itemId, 'cash', { voucherCode: code });
      await post(merchant.token, `/v1/food/orders/${order.id}/accept`).expect(200);
      await post(merchant.token, `/v1/food/orders/${order.id}/ready`).expect(200);
      await post(d.token, `/v1/food/orders/${order.id}/claim`).expect(200);
      const driverView = await get(d.token, `/v1/food/orders/${order.id}`).expect(200);
      expect(driverView.body.data.cashPlan).toEqual({
        payMerchantVnd: order.subtotalVnd - 7_000,
        collectFromCustomerVnd: order.totalVnd,
        platformOwesDriverVnd: 3_000,
      });
      const customerView = await get(customer.token, `/v1/food/orders/${order.id}`).expect(200);
      expect(customerView.body.data).not.toHaveProperty('cashPlan');
      const deliveryCode = customerView.body.data.deliveryCode as string;
      await post(d.token, `/v1/food/orders/${order.id}/pickup`).expect(200);
      await post(d.token, `/v1/food/orders/${order.id}/deliver`, { deliveryCode }).expect(200);
      const adjustments = await app.get(EarningsService).listAdjustments(d.userId);
      expect(adjustments).toEqual([
        expect.objectContaining({ kind: 'FOOD_DISCOUNT_REIMBURSED', amountVnd: -3_000, refId: order.id }),
      ]);
    });
  });
});
