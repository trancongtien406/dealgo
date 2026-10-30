import { seedMotorbikeOnDriverGrant } from './motorbike-drivers.js';
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
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { CatalogModule } from '../../../src/modules/catalog/catalog.module.js';
import { FoodModule } from '../../../src/modules/food-order/food.module.js';
import { FOOD_REPOSITORY } from '../../../src/modules/food-order/food.constants.js';
import { MemoryFoodRepository } from '../../../src/modules/food-order/food.repository.js';
import { PROMOTION_REPOSITORY } from '../../../src/modules/promotion/promotion.constants.js';
import type { PromotionRepository } from '../../../src/modules/promotion/promotion.repository.js';
import { PlatformSettingsService } from '../../../src/platform/settings/platform-settings.service.js';
import { EarningsService } from '../../../src/modules/earnings/earnings.service.js';
import { FoodService } from '../../../src/modules/food-order/food.service.js';
import { EARNINGS_REPOSITORY } from '../../../src/modules/earnings/earnings.constants.js';
import type { EarningsRepository } from '../../../src/modules/earnings/earnings.repository.js';
import { LEDGER_REPOSITORY } from '../../../src/modules/ledger/ledger.constants.js';
import type { MemoryLedgerRepository } from '../../../src/modules/ledger/ledger.repository.js';
import { CHECKOUT_REPOSITORY } from '../../../src/modules/payment/payment.constants.js';
import type { MemoryCheckoutRepository } from '../../../src/modules/payment/checkout/checkout.repository.js';

const dropoff = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };

/**
 * food dispatch gaps (Page numbering): early claim (16), driver release + fail-after-pickup and
 * timeouts (6), max delivery distance (13), fresh presence + debt limit (1/10/15), cash plan (15).
 * Catalog defaults: lead 10 min, accept timeout 5 min, unclaimed READY 30 min, 15 km, 200 000 VND.
 */
describe('food dispatch http', () => {
  let app: INestApplication;
  let repository: MemoryIdentityRepository;
  let sms: MockSmsSender;
  let phoneSerial = 700;

  beforeAll(async () => {
    repository = new MemoryIdentityRepository();
    sms = new MockSmsSender('test');

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
              FOOD_MIN_DELIVERY_VND: '5000',
              FOOD_MAX_DELIVERY_VND: '100000',
              FOOD_DELIVERY_VND_PER_KM: '3000',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
              PARTNER_ELIGIBILITY_BYPASS: 'true',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        FoodModule,
        CatalogModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(repository)
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    seedMotorbikeOnDriverGrant(repository, app);
    // These suites exercise the delivery-code flow; the shipped default is off.
    await app
      .get(PlatformSettingsService)
      .patch('FOOD_DELIVERY_CODE_REQUIRED', 'true', 'code suites', 'ops-test');
  });

  afterAll(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());
  const MERCHANT_PHONE = '0901110001';
  const settings = () => app.get(PlatformSettingsService);

  async function onlineDriver(): Promise<{ token: string; userId: string }> {
    const d = await login();
    await repository.insertGrant(d.userId, 'DRIVER', 'ACTIVE');
    await http()
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${d.token}`)
      .send({ online: true, lat: dropoff.lat + 0.002, lng: dropoff.lng + 0.002 })
      .expect(200);
    return d;
  }

  async function placeAccepted(customer: { token: string }, merchant: { token: string }, key: string) {
    const { storeId, itemId } = await oneItem(customer.token);
    const created = await place(customer.token, key, storeId, [{ itemId, quantity: 1 }]);
    expect(created.status).toBe(200);
    const orderId = created.body.data.id as string;
    await http().post(`/v1/food/orders/${orderId}/accept`).set('Authorization', `Bearer ${merchant.token}`).expect(200);
    return orderId;
  }

  async function withSetting<T>(key: string, value: string, run: () => Promise<T>, reset: string): Promise<T> {
    await settings().patch(key as never, value, 'test', 'ops-test');
    try {
      return await run();
    } finally {
      await settings().patch(key as never, reset, 'test reset', 'ops-test');
    }
  }

  it('early claim opens prep − lead minutes after accept; ready → ASSIGNED', async () => {
    const customer = await login();
    const merchant = await loginPhone(MERCHANT_PHONE);
    const d = await onlineDriver();
    const orderId = await placeAccepted(customer, merchant, 'food-early');

    // Default lead 10 min, prep 15 min → opens 5 min after accept: not yet.
    const notYet = await http().post(`/v1/food/orders/${orderId}/claim`).set('Authorization', `Bearer ${d.token}`);
    expect(notYet.status).toBe(409);
    expect(notYet.body.errorCode).toBe('FOOD_NOT_YET_CLAIMABLE');
    const hidden = await http().get('/v1/food/orders/ready').set('Authorization', `Bearer ${d.token}`).expect(200);
    expect((hidden.body.data as { id: string }[]).map((o) => o.id)).not.toContain(orderId);

    await withSetting('FOOD_EARLY_ASSIGN_LEAD_MINUTES', '15', async () => {
      const listed = await http().get('/v1/food/orders/ready').set('Authorization', `Bearer ${d.token}`).expect(200);
      const row = (listed.body.data as { id: string; status: string; estimatedReadyAt: string }[]).find(
        (o) => o.id === orderId,
      );
      expect(row?.status).toBe('PREPARING');
      expect(row?.estimatedReadyAt).toEqual(expect.any(String));
      const claimed = await http().post(`/v1/food/orders/${orderId}/claim`).set('Authorization', `Bearer ${d.token}`).expect(200);
      expect(claimed.body.data).toMatchObject({ status: 'PREPARING', assignedDriverId: d.userId });
    }, '10');

    // Still cooking: no pickup yet.
    await http().post(`/v1/food/orders/${orderId}/pickup`).set('Authorization', `Bearer ${d.token}`).expect(409);
    const ready = await http().post(`/v1/food/orders/${orderId}/ready`).set('Authorization', `Bearer ${merchant.token}`).expect(200);
    expect(ready.body.data).toMatchObject({ status: 'ASSIGNED', assignedDriverId: d.userId });
    await http().post(`/v1/food/orders/${orderId}/pickup`).set('Authorization', `Bearer ${d.token}`).expect(200);
  });

  it('release needs a reason, only the assigned driver, returns the order to the pool', async () => {
    const customer = await login();
    const merchant = await loginPhone(MERCHANT_PHONE);
    const d = await onlineDriver();
    const other = await onlineDriver();
    const orderId = await claimReadyOrder(customer, merchant, d, 'food-release');

    await http().post(`/v1/food/orders/${orderId}/release`).set('Authorization', `Bearer ${d.token}`).send({}).expect(400);
    await http()
      .post(`/v1/food/orders/${orderId}/release`)
      .set('Authorization', `Bearer ${d.token}`)
      .send({ reasonCode: 'NOT_A_REASON' })
      .expect(400);
    const notMine = await http()
      .post(`/v1/food/orders/${orderId}/release`)
      .set('Authorization', `Bearer ${other.token}`)
      .send({ reasonCode: 'STORE_TOO_SLOW' });
    expect(notMine.status).toBe(403);

    // Before pickup "fail" is no longer allowed: the food is still at the store.
    const early = await http()
      .post(`/v1/food/orders/${orderId}/fail`)
      .set('Authorization', `Bearer ${d.token}`)
      .send({ reasonCode: 'CUSTOMER_REFUSED' });
    expect(early.status).toBe(409);

    const released = await http()
      .post(`/v1/food/orders/${orderId}/release`)
      .set('Authorization', `Bearer ${d.token}`)
      .send({ reasonCode: 'STORE_TOO_SLOW' })
      .expect(200);
    expect(released.body.data).toMatchObject({ status: 'READY', assignedDriverId: null });
    const repo = app.get<MemoryFoodRepository>(FOOD_REPOSITORY);
    expect(repo.driverCancellations.filter((row) => row.orderId === orderId)).toEqual([
      expect.objectContaining({ driverId: d.userId, reasonCode: 'STORE_TOO_SLOW', fromStatus: 'ASSIGNED' }),
    ]);

    // Another driver picks it up from the pool; fail is allowed after pickup.
    await http().post(`/v1/food/orders/${orderId}/claim`).set('Authorization', `Bearer ${other.token}`).expect(200);
    await http().post(`/v1/food/orders/${orderId}/pickup`).set('Authorization', `Bearer ${other.token}`).expect(200);
    const fail = (body: object) =>
      http().post(`/v1/food/orders/${orderId}/fail`).set('Authorization', `Bearer ${other.token}`).send(body);
    // A reason is required; OTHER needs a note; "unreachable" needs the wait.
    expect((await fail({})).status).toBe(400);
    const noNote = await fail({ reasonCode: 'OTHER' });
    expect(noNote.status).toBe(400);
    expect(noNote.body.errorCode).toBe('FOOD_FAIL_NOTE_REQUIRED');
    const tooEarly = await fail({ reasonCode: 'CUSTOMER_UNREACHABLE' });
    expect(tooEarly.status).toBe(409);
    expect(tooEarly.body.errorCode).toBe('FOOD_FAIL_TOO_EARLY');
    const before = await app.get<EarningsRepository>(EARNINGS_REPOSITORY).balanceOf(other.userId);
    const failed = await fail({ reasonCode: 'CUSTOMER_REFUSED', note: 'Khách đổi ý' });
    expect(failed.status).toBe(200);
    expect(failed.body.data).toMatchObject({
      status: 'FAILED',
      failReason: { code: 'CUSTOMER_REFUSED', note: 'Khách đổi ý' },
      pickedUpAt: expect.any(String),
    });
    const merchantCash = failed.body.data.merchantCashVnd as number;
    expect(merchantCash).toBeGreaterThan(0);
    // The driver already paid the store; DealGo credits that cash back.
    const after = await app.get<EarningsRepository>(EARNINGS_REPOSITORY).balanceOf(other.userId);
    expect(after.amountVnd).toBe(before.amountVnd - merchantCash);
    expect(repo.driverCancellations.filter((row) => row.orderId === orderId)).toHaveLength(1);
  });

  it('quote and place refuse a drop-off beyond FOOD_MAX_DELIVERY_KM', async () => {
    const customer = await login();
    const merchant = await loginPhone(MERCHANT_PHONE);
    const { storeId, itemId } = await oneItem(customer.token);
    // A pin outside every active service zone is refused (Huế-bound, north of Hải Vân).
    const outside = await http()
      .patch('/v1/food/merchant/store/location')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ lat: dropoff.lat + 0.2, lng: dropoff.lng, addressLabel: 'Outside zone' });
    expect(outside.status).toBe(422);
    expect(outside.body.errorCode).toBe('FOOD_OUTSIDE_SERVICE_ZONE');
    // Store ~19 km north of the drop-off, still inside the Đà Nẵng zone.
    await http()
      .patch('/v1/food/merchant/store/location')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ lat: dropoff.lat + 0.17, lng: dropoff.lng, addressLabel: 'Far away' })
      .expect(200);
    try {
      const quote = await http().post('/v1/food/quote').set('Authorization', `Bearer ${customer.token}`).send({ storeId, dropoff });
      expect(quote.status).toBe(422);
      expect(quote.body.errorCode).toBe('FOOD_TOO_FAR');
      const placed = await place(customer.token, 'food-far', storeId, [{ itemId, quantity: 1 }]);
      expect(placed.status).toBe(422);
      expect(placed.body.errorCode).toBe('FOOD_TOO_FAR');
      await withSetting('FOOD_MAX_DELIVERY_KM', '30', async () => {
        await http().post('/v1/food/quote').set('Authorization', `Bearer ${customer.token}`).send({ storeId, dropoff }).expect(200);
      }, '15');
    } finally {
      await http()
        .patch('/v1/food/merchant/store/location')
        .set('Authorization', `Bearer ${merchant.token}`)
        .send({ lat: dropoff.lat, lng: dropoff.lng, addressLabel: '12 Bạch Đằng, Hải Châu' })
        .expect(200);
    }
    await http().post('/v1/food/quote').set('Authorization', `Bearer ${customer.token}`).send({ storeId, dropoff }).expect(200);
  });

  it('ready pool needs a fresh fix, sorts nearest first, and blocks indebted or offline drivers', async () => {
    const customer = await login();
    const merchant = await loginPhone(MERCHANT_PHONE);
    const orderId = await placeAccepted(customer, merchant, 'food-pool');
    await http().post(`/v1/food/orders/${orderId}/ready`).set('Authorization', `Bearer ${merchant.token}`).expect(200);

    const noFix = await login();
    await repository.insertGrant(noFix.userId, 'DRIVER', 'ACTIVE');
    await http().post('/v1/me/presence').set('Authorization', `Bearer ${noFix.token}`).send({ online: true }).expect(200);
    const stale = await http().get('/v1/food/orders/ready').set('Authorization', `Bearer ${noFix.token}`);
    expect(stale.status).toBe(409);
    expect(stale.body.errorCode).toBe('DRIVER_LOCATION_STALE');

    // Far from Đà Nẵng (Hà Nội fix): the order is outside the search radius.
    const far = await login();
    await repository.insertGrant(far.userId, 'DRIVER', 'ACTIVE');
    await http().post('/v1/me/presence').set('Authorization', `Bearer ${far.token}`).send({ online: true, lat: 21.0285, lng: 105.8542 }).expect(200);
    const farList = await http().get('/v1/food/orders/ready').set('Authorization', `Bearer ${far.token}`).expect(200);
    expect((farList.body.data as { id: string }[]).map((o) => o.id)).not.toContain(orderId);

    const d = await onlineDriver();
    const near = await http().get('/v1/food/orders/ready').set('Authorization', `Bearer ${d.token}`).expect(200);
    expect((near.body.data as { id: string }[]).map((o) => o.id)).toContain(orderId);

    // Offline drivers cannot claim.
    await http().post('/v1/me/presence').set('Authorization', `Bearer ${far.token}`).send({ online: false }).expect(200);
    const offline = await http().post(`/v1/food/orders/${orderId}/claim`).set('Authorization', `Bearer ${far.token}`);
    expect(offline.status).toBe(409);
    expect(offline.body.errorCode).toBe('DRIVER_OFFLINE');

    // Over DRIVER_DEBT_LIMIT_VND (200 000): no pool, no claim.
    await app.get(EarningsService).adjustWithin(undefined as never, {
      driverId: d.userId,
      amountVnd: 200_001,
      kind: 'MANUAL',
      refType: 'TEST',
      refId: '00000000-0000-4000-8000-0000000000d1',
      occurredAt: new Date(),
    });
    const blocked = await http().get('/v1/food/orders/ready').set('Authorization', `Bearer ${d.token}`);
    expect(blocked.status).toBe(403);
    expect(blocked.body.errorCode).toBe('DRIVER_DEBT_LIMIT_REACHED');
    const blockedClaim = await http().post(`/v1/food/orders/${orderId}/claim`).set('Authorization', `Bearer ${d.token}`);
    expect(blockedClaim.status).toBe(403);
  });

  it('cash model: assigned driver sees the cash plan; platform-funded voucher share is credited back', async () => {
    const promotions = app.get<PromotionRepository>(PROMOTION_REPOSITORY);
    const now = Date.now();
    await promotions.create({
      code: 'R18SHARE10K',
      name: 'R18SHARE10K',
      description: 'dispatch test',
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
    await settings().patch('VOUCHER_SHARED_PLATFORM_PERCENT', '30', 'split', 'ops-test');
    try {
      const customer = await login();
      const merchant = await loginPhone(MERCHANT_PHONE);
      const d = await onlineDriver();
      const { storeId, itemId } = await oneItem(customer.token);
      const placed = await http()
        .post('/v1/food/orders')
        .set('Authorization', `Bearer ${customer.token}`)
        .set('Idempotency-Key', 'food-cash')
        .send({ storeId, items: [{ itemId, quantity: 1 }], dropoff, voucherCode: 'R18SHARE10K' })
        .expect(200);
      const order = placed.body.data as { id: string; subtotalVnd: number; totalVnd: number };
      for (const [actor, step] of [
        [merchant, 'accept'],
        [merchant, 'ready'],
        [d, 'claim'],
      ] as const) {
        await http().post(`/v1/food/orders/${order.id}/${step}`).set('Authorization', `Bearer ${actor.token}`).expect(200);
      }
      const driverView = await http().get(`/v1/food/orders/${order.id}`).set('Authorization', `Bearer ${d.token}`).expect(200);
      expect(driverView.body.data.cashPlan).toEqual({
        payMerchantVnd: order.subtotalVnd - 7_000,
        collectFromCustomerVnd: order.totalVnd,
        platformOwesDriverVnd: 3_000,
      });
      const customerView = await http().get(`/v1/food/orders/${order.id}`).set('Authorization', `Bearer ${customer.token}`).expect(200);
      expect(customerView.body.data).not.toHaveProperty('cashPlan');

      await http().post(`/v1/food/orders/${order.id}/pickup`).set('Authorization', `Bearer ${d.token}`).expect(200);
      const deliveryCode = await deliveryCodeOf(customer.token, order.id);
      await http()
        .post(`/v1/food/orders/${order.id}/deliver`)
        .set('Authorization', `Bearer ${d.token}`)
        .send({ deliveryCode })
        .expect(200);
      const adjustments = await app.get(EarningsService).listAdjustments(d.userId);
      expect(adjustments).toEqual([
        expect.objectContaining({ kind: 'FOOD_DISCOUNT_REIMBURSED', amountVnd: -3_000, refId: order.id }),
      ]);

      // Merchant statement by ICT day — cash received, 20% commission owed, net.
      const statement = await http()
        .get('/v1/food/merchant/statement')
        .set('Authorization', `Bearer ${merchant.token}`)
        .expect(200);
      const st = statement.body.data as {
        timezone: string;
        storeId: string;
        days: Array<{ date: string; orderCount: number }>;
        totals: Record<string, number>;
        unsettledCommissionVnd: number;
        from: string;
        to: string;
      };
      expect(st.timezone).toBe('Asia/Ho_Chi_Minh');
      expect(st.days).toHaveLength(7);
      const commission = Math.round(order.subtotalVnd * 0.2);
      expect(st.totals).toMatchObject({
        orderCount: 1,
        grossVnd: order.subtotalVnd,
        merchantFundedVnd: 7_000,
        cashReceivedVnd: order.subtotalVnd - 7_000,
        commissionVnd: commission,
        netVnd: order.subtotalVnd - 7_000 - commission,
      });
      expect(st.unsettledCommissionVnd).toBe(commission);
      expect(st.days.at(-1)).toMatchObject({ date: st.to, orderCount: 1 });
      await http()
        .get('/v1/food/merchant/statement?from=2026-01-01&to=2026-03-01')
        .set('Authorization', `Bearer ${merchant.token}`)
        .expect(400);
      // Ops can only settle closed days and never overlapping periods.
      const food = app.get(FoodService);
      const opsActor = { userId: d.userId } as never;
      await expect(
        food.opsRecordMerchantSettlement(opsActor, st.storeId, { from: st.to, to: st.to, reason: 'today' }),
      ).rejects.toMatchObject({ status: 409 });
      const settled = await food.opsRecordMerchantSettlement(opsActor, st.storeId, {
        from: st.from,
        to: st.days.at(-2)!.date,
        reason: 'weekly payout',
      });
      expect(settled).toMatchObject({ periodStart: st.from, orderCount: 0, commissionVnd: 0 });
      await expect(
        food.opsRecordMerchantSettlement(opsActor, st.storeId, { from: st.from, to: st.from, reason: 'dup' }),
      ).rejects.toMatchObject({ status: 409 });
      const after = await food.opsMerchantStatement(st.storeId, st.from, st.to);
      expect(after.settlements).toHaveLength(1);
      expect(after.unsettledCommissionVnd).toBe(commission);
    } finally {
      await settings().patch('VOUCHER_SHARED_PLATFORM_PERCENT', '100', 'reset', 'ops-test');
    }
  });

  /** Places, readies, claims and picks up an order the customer prepaid online (MoMo). */
  async function onlinePaidOrder(key: string, refundedVnd = 0) {
    const customer = await login();
    const merchant = await loginPhone(MERCHANT_PHONE);
    const d = await onlineDriver();
    const orderId = await placeAccepted(customer, merchant, key);
    const total = (await http().get(`/v1/food/orders/${orderId}`).set('Authorization', `Bearer ${customer.token}`).expect(200))
      .body.data.totalVnd as number;
    const checkout = app.get<MemoryCheckoutRepository>(CHECKOUT_REPOSITORY, { strict: false });
    await checkout.setSelection('FOOD_ORDER', orderId, 'MOMO');
    const intent = await checkout.upsertAttempt({
      entityType: 'FOOD_ORDER', entityId: orderId, method: 'MOMO', methodCode: 'MOMO', provider: 'momo',
      amountVnd: total, providerRef: `DGF${key}`.slice(0, 20), paymentUrl: null, deeplink: null,
    });
    await checkout.update(intent.id, { status: 'CAPTURED', providerTransId: key, refundedVnd });
    for (const [actor, step] of [
      [merchant, 'ready'],
      [d, 'claim'],
      [d, 'pickup'],
    ] as const) {
      await http().post(`/v1/food/orders/${orderId}/${step}`).set('Authorization', `Bearer ${actor.token}`).expect(200);
    }
    return { customer, d, orderId, total, intentId: intent.id, checkout };
  }

  async function deliver(customerToken: string, driverToken: string, orderId: string) {
    const deliveryCode = await deliveryCodeOf(customerToken, orderId);
    await http()
      .post(`/v1/food/orders/${orderId}/deliver`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ deliveryCode })
      .expect(200);
  }

  it('online-paid food order: driver collects nothing, no COD, prepaid applied and paid out to the driver', async () => {
    const { customer, d, orderId, total, intentId, checkout } = await onlinePaidOrder('food-online-full');
    const before = await http().get(`/v1/food/orders/${orderId}/collection`).set('Authorization', `Bearer ${d.token}`).expect(200);
    expect(before.body.data).toMatchObject({ methodCode: 'MOMO', status: 'PAID', paidOnlineVnd: total, cashToCollectVnd: 0 });
    // Only the assigned driver reads the collection split.
    await http().get(`/v1/food/orders/${orderId}/collection`).set('Authorization', `Bearer ${customer.token}`).expect(404);

    await deliver(customer.token, d.token, orderId);

    const ledgerRepo = app.get<MemoryLedgerRepository>(LEDGER_REPOSITORY, { strict: false });
    expect(await ledgerRepo.findByEntity('FOOD_ORDER', orderId, 'COD_OBLIGATION_POSTED')).toBeNull();
    expect((await ledgerRepo.findByEntity('FOOD_ORDER', orderId, 'PSP_PREPAID_APPLIED'))?.amountVnd).toBe(total);
    expect((await checkout.findById(intentId))?.settledAt).toBeInstanceOf(Date);
    const adjustments = await app.get(EarningsService).listAdjustments(d.userId);
    expect(adjustments).toEqual([
      expect.objectContaining({ kind: 'ONLINE_PAYMENT_PAYOUT', amountVnd: -total, refId: intentId }),
    ]);
  });

  it('partly refunded online payment: driver collects only the remainder in cash', async () => {
    const refunded = 5_000;
    const { customer, d, orderId, total } = await onlinePaidOrder('food-online-part', refunded);
    const before = await http().get(`/v1/food/orders/${orderId}/collection`).set('Authorization', `Bearer ${d.token}`).expect(200);
    expect(before.body.data).toMatchObject({ paidOnlineVnd: total - refunded, cashToCollectVnd: refunded });

    await deliver(customer.token, d.token, orderId);

    const ledgerRepo = app.get<MemoryLedgerRepository>(LEDGER_REPOSITORY, { strict: false });
    expect((await ledgerRepo.findByEntity('FOOD_ORDER', orderId, 'COD_OBLIGATION_POSTED'))?.amountVnd).toBe(refunded);
    expect((await ledgerRepo.findByEntity('FOOD_ORDER', orderId, 'PSP_PREPAID_APPLIED'))?.amountVnd).toBe(total - refunded);
  });

  it('merchant-accept and unclaimed-READY timeouts cancel as SYSTEM (worker sweep)', async () => {
    const customer = await login();
    const merchant = await loginPhone(MERCHANT_PHONE);
    const { storeId, itemId } = await oneItem(customer.token);
    const placed = await place(customer.token, 'food-timeout-placed', storeId, [{ itemId, quantity: 1 }]);
    const placedId = placed.body.data.id as string;
    const readyCustomer = await login();
    const readyId = await placeAccepted(readyCustomer, merchant, 'food-timeout-ready');
    await http().post(`/v1/food/orders/${readyId}/ready`).set('Authorization', `Bearer ${merchant.token}`).expect(200);

    const food = app.get(FoodService);
    expect((await food.timeoutDue(new Date(Date.now() + 4 * 60_000))).orderIds).not.toContain(placedId);
    const first = await food.timeoutDue(new Date(Date.now() + 6 * 60_000));
    expect(first.orderIds).toContain(placedId);
    expect(first.orderIds).not.toContain(readyId);
    const second = await food.timeoutDue(new Date(Date.now() + 31 * 60_000));
    expect(second.orderIds).toContain(readyId);

    const placedView = await http().get(`/v1/food/orders/${placedId}`).set('Authorization', `Bearer ${customer.token}`).expect(200);
    expect(placedView.body.data).toMatchObject({ status: 'CANCELLED', cancelledBy: 'SYSTEM' });
    expect(placedView.body.data.cancelReason).toMatchObject({ code: 'MERCHANT_TIMEOUT' });
    const readyView = await http().get(`/v1/food/orders/${readyId}`).set('Authorization', `Bearer ${readyCustomer.token}`).expect(200);
    expect(readyView.body.data).toMatchObject({ status: 'CANCELLED', cancelledBy: 'SYSTEM' });
    expect(readyView.body.data.cancelReason).toMatchObject({ code: 'NO_DRIVER' });
  });

  async function deliveryCodeOf(customerToken: string, orderId: string): Promise<string> {
    const order = await request(app.getHttpServer())
      .get(`/v1/food/orders/${orderId}`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(200);
    expect(order.body.data.deliveryCode).toMatch(/^\d{4}$/);
    return order.body.data.deliveryCode as string;
  }

  async function claimReadyOrder(
    customer: { token: string },
    merchant: { token: string },
    driver: { token: string },
    idempotencyKey: string,
  ): Promise<string> {
    const { storeId, itemId } = await oneItem(customer.token);
    const created = await place(customer.token, idempotencyKey, storeId, [{ itemId, quantity: 1 }]);
    expect(created.status).toBe(200);
    const orderId = created.body.data.id as string;
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/accept`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/ready`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    const claimed = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/claim`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(claimed.body.data.status).toBe('ASSIGNED');
    return orderId;
  }

  async function login(): Promise<{ token: string; userId: string }> {
    phoneSerial += 1;
    return loginPhone(`091${String(phoneSerial).padStart(7, '0')}`);
  }

  async function loginPhone(phone: string): Promise<{ token: string; userId: string }> {
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

  async function oneItem(token: string): Promise<{ storeId: string; itemId: string }> {
    const catalog = await request(app.getHttpServer())
      .get('/v1/food/stores')
      .query({ search: 'Bún Bò Huế', limit: 20 })
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const store = (catalog.body.data.items as { id: string; name: string }[]).find(
      (entry) => entry.name === 'Bún Bò Huế',
    );
    expect(store).toBeDefined();
    const storeId = store!.id;
    const detail = await request(app.getHttpServer())
      .get(`/v1/food/stores/${storeId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    return { storeId, itemId: detail.body.data.items[0].id as string };
  }

  function place(
    token: string,
    idempotencyKey: string,
    storeId: string,
    items: { itemId: string; quantity: number; optionIds?: string[] }[],
  ) {
    return request(app.getHttpServer())
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idempotencyKey)
      .send({ storeId, items, dropoff, deliveryFareVnd: 15_000 });
  }
});
