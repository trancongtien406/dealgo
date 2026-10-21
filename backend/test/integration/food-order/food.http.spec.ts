import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { maskPersonName } from '../../../src/shared/privacy/pii-mask.js';
import { createValidationPipe } from '../../../src/platform/http/create-validation-pipe.js';
import { HttpExceptionFilter } from '../../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../../src/platform/http/response.interceptor.js';
import { loadEnv } from '../../../src/platform/config/env.js';
import { IDENTITY_REPOSITORY, SMS_SENDER } from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { CatalogModule } from '../../../src/modules/catalog/catalog.module.js';
import { FOOD_REPOSITORY } from '../../../src/modules/food-order/food.constants.js';
import { FoodModule } from '../../../src/modules/food-order/food.module.js';
import { MemoryFoodRepository } from '../../../src/modules/food-order/food.repository.js';
import { LEDGER_REPOSITORY } from '../../../src/modules/ledger/ledger.constants.js';
import type { LedgerRepository } from '../../../src/modules/ledger/ledger.repository.js';
import { PROMOTION_REPOSITORY } from '../../../src/modules/promotion/promotion.constants.js';
import type { PromotionRepository } from '../../../src/modules/promotion/promotion.repository.js';
import { vnClock } from '../../../src/modules/food-order/store-schedule.js';
import { PlatformSettingsService } from '../../../src/platform/settings/platform-settings.service.js';

const OPS_EMAIL = 'ops@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';
const dropoff = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };

describe('food order http', () => {
  let app: INestApplication;
  let repository: MemoryIdentityRepository;
  let sms: MockSmsSender;
  let phoneSerial = 200;

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
    await app.get(OpsAuthService).ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');
  });

  afterAll(async () => {
    await app.close();
  });

  it('snapshots catalog prices and replays the same idempotency key', async () => {
    const customer = await login();
    const catalog = await request(app.getHttpServer())
      .get('/v1/food/stores')
      .query({ search: 'Bún Bò Huế' })
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    const store = catalog.body.data.items[0] as { id: string; name: string };
    expect(store.name).toBe('Bún Bò Huế');

    const detail = await request(app.getHttpServer())
      .get(`/v1/food/stores/${store.id}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    const items = detail.body.data.items as { id: string; name: string; priceVnd: number }[];
    const bun = items.find((item) => item.name === 'Bún bò đặc biệt');
    const tea = items.find((item) => item.name === 'Trà tắc');
    expect(bun?.priceVnd).toBe(60_000);
    expect(tea?.priceVnd).toBe(25_000);

    const first = await place(customer.token, 'idem-food-snapshot-1', store.id, [
      { itemId: bun!.id, quantity: 2 },
      { itemId: tea!.id, quantity: 1 },
    ]);
    expect(first.status).toBe(200);
    expect(first.body.data.subtotalVnd).toBe(145_000);
    // Fixture store has no lat/lng → server quotes FOOD_MIN_DELIVERY_VND.
    expect(first.body.data.deliveryFareVnd).toBe(5_000);
    expect(first.body.data.totalVnd).toBe(150_000);
    expect(first.body.data.status).toBe('PLACED');

    const replay = await place(customer.token, 'idem-food-snapshot-1', store.id, [
      { itemId: bun!.id, quantity: 1 },
    ]);
    expect(replay.status).toBe(200);
    expect(replay.body.data.id).toBe(first.body.data.id);
    expect(replay.body.data.subtotalVnd).toBe(145_000);
  });

  it('paginates store browse and rejects invalid query params', async () => {
    const customer = await login();
    const page = await request(app.getHttpServer())
      .get('/v1/food/stores')
      .query({ page: 1, limit: 20, search: '' })
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(page.body.data).toMatchObject({
      page: 1,
      limit: 20,
      total: expect.any(Number),
    });
    expect(Array.isArray(page.body.data.items)).toBe(true);
    expect(page.body.data.items[0]).toMatchObject({
      id: expect.any(String),
      name: 'Bún Bò Huế',
      category: 'pho',
      createdAt: expect.any(String),
      distanceKm: null,
    });

    const emptySearch = await request(app.getHttpServer())
      .get('/v1/food/stores')
      .query({ search: '   ' })
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(emptySearch.body.data.total).toBe(page.body.data.total);

    await request(app.getHttpServer())
      .get('/v1/food/stores')
      .query({ limit: 101 })
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(400);

    await request(app.getHttpServer())
      .get('/v1/food/stores')
      .query({ sort_by: 'popularity' })
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(400);

    await request(app.getHttpServer())
      .get('/v1/food/stores')
      .query({ lat: 10.77 })
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(400);
  });

  it('quotes the delivery fare that placement charges', async () => {
    const customer = await login();
    const { storeId, itemId } = await oneItem(customer.token);
    const dropoff = { lat: 16.07, lng: 108.21, label: '12 Nguyễn Văn Linh' };
    const quote = await request(app.getHttpServer())
      .post('/v1/food/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ storeId, dropoff })
      .expect(200);
    expect(quote.body.data.deliveryFareVnd).toBeGreaterThan(0);
    const placed = await request(app.getHttpServer())
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'idem-food-quote-1')
      .send({ storeId, items: [{ itemId, quantity: 1 }], dropoff, deliveryFareVnd: 1 })
      .expect(200);
    expect(placed.body.data.deliveryFareVnd).toBe(quote.body.data.deliveryFareVnd);
    await request(app.getHttpServer())
      .post('/v1/food/quote')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ storeId: '00000000-0000-4000-8000-000000000000', dropoff })
      .expect(404);
  });

  it('rejects a second open order', async () => {
    const customer = await login();
    const { storeId, itemId } = await oneItem(customer.token);
    const first = await place(customer.token, 'idem-food-open-1', storeId, [{ itemId, quantity: 1 }]);
    expect(first.status).toBe(200);
    const second = await place(customer.token, 'idem-food-open-2', storeId, [{ itemId, quantity: 1 }]);
    expect(second.status).toBe(409);
    expect(second.body.errorCode).toBe('FOOD_ORDER_ALREADY_OPEN');
  });

  it('hides the order from another store merchant and another customer', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const otherMerchant = await login();
    await repository.insertGrant(otherMerchant.userId, 'MERCHANT', 'ACTIVE');
    const stranger = await login();

    const { storeId, itemId } = await oneItem(customer.token);
    const created = await place(customer.token, 'idem-food-owner-1', storeId, [{ itemId, quantity: 1 }]);
    expect(created.status).toBe(200);
    const orderId = created.body.data.id as string;

    const accepted = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/accept`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    expect(accepted.body.data.status).toBe('PREPARING');

    const denied = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/accept`)
      .set('Authorization', `Bearer ${otherMerchant.token}`);
    expect(denied.status).toBe(404);
    expect(denied.body.errorCode).toBe('FOOD_ORDER_NOT_FOUND');

    const hidden = await request(app.getHttpServer())
      .get(`/v1/food/orders/${orderId}`)
      .set('Authorization', `Bearer ${stranger.token}`);
    expect(hidden.status).toBe(404);
    expect(hidden.body.errorCode).toBe('FOOD_ORDER_NOT_FOUND');
  });

  it('lets one driver claim a ready order and rejects the second', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const firstDriver = await login();
    const secondDriver = await login();
    await repository.insertGrant(firstDriver.userId, 'DRIVER', 'ACTIVE');
    await repository.insertGrant(secondDriver.userId, 'DRIVER', 'ACTIVE');

    const { storeId, itemId } = await oneItem(customer.token);
    const created = await place(customer.token, 'idem-food-claim-1', storeId, [{ itemId, quantity: 1 }]);
    const orderId = created.body.data.id as string;

    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/accept`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/ready`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);

    const [winner, loser] = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/food/orders/${orderId}/claim`)
        .set('Authorization', `Bearer ${firstDriver.token}`),
      request(app.getHttpServer())
        .post(`/v1/food/orders/${orderId}/claim`)
        .set('Authorization', `Bearer ${secondDriver.token}`),
    ]);
    const statuses = [winner.status, loser.status].sort((a, b) => a - b);
    expect(statuses).toEqual([200, 409]);
    const assigned = winner.status === 200 ? winner : loser;
    const rejected = winner.status === 409 ? winner : loser;
    expect(assigned.body.data.status).toBe('ASSIGNED');
    expect(assigned.body.data.assignedDriverId).toBe(
      winner.status === 200 ? firstDriver.userId : secondDriver.userId,
    );
    expect(rejected.body.errorCode).toBe('FOOD_ALREADY_ASSIGNED');
  });

  it('lists a ready order to an active driver and omits a placed order', async () => {
    const placedCustomer = await login();
    const readyCustomer = await login();
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');

    const placedCatalog = await oneItem(placedCustomer.token);
    const placed = await place(placedCustomer.token, 'idem-food-ready-placed', placedCatalog.storeId, [
      { itemId: placedCatalog.itemId, quantity: 1 },
    ]);
    expect(placed.status).toBe(200);

    const readyCatalog = await oneItem(readyCustomer.token);
    const created = await place(readyCustomer.token, 'idem-food-ready-list', readyCatalog.storeId, [
      { itemId: readyCatalog.itemId, quantity: 1 },
    ]);
    expect(created.status).toBe(200);
    const orderId = created.body.data.id as string;
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/accept`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    const ready = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/ready`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);

    const listed = await request(app.getHttpServer())
      .get('/v1/food/orders/ready')
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    const ids = (listed.body.data as { id: string }[]).map((order) => order.id);
    expect(ids).toContain(orderId);
    expect(ids).not.toContain(placed.body.data.id);
    const match = (listed.body.data as { id: string }[]).find((order) => order.id === orderId);
    expect(match).toEqual({
      id: orderId,
      storeId: readyCatalog.storeId,
      storeName: ready.body.data.storeName,
      storeAddress: null,
      status: 'READY',
      deliveryFareVnd: ready.body.data.deliveryFareVnd,
      subtotalVnd: ready.body.data.subtotalVnd,
      totalVnd: ready.body.data.totalVnd,
      dropoff,
      lineCount: (ready.body.data.lines as unknown[]).length,
      store: null,
      pickup: null,
    });
    expect(JSON.stringify(listed.body.data)).not.toContain('"phone"');
  });

  it('rejects a customer without a driver grant from ready food orders', async () => {
    const customer = await login();
    const { storeId, itemId } = await oneItem(customer.token);
    const placed = await place(customer.token, 'idem-food-ready-denied', storeId, [{ itemId, quantity: 1 }]);
    expect(placed.status).toBe(200);

    const denied = await request(app.getHttpServer())
      .get('/v1/food/orders/ready')
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(403);
    expect(denied.body.errorCode).toBe('ROLE_NOT_ACTIVE');
  });

  it('lists placed orders for the fixture merchant and hides another store', async () => {
    const customer = await login();
    const otherCustomer = await login();
    const merchant = await loginPhone('0901110001');
    const otherMerchant = await login();
    await repository.insertGrant(otherMerchant.userId, 'MERCHANT', 'ACTIVE');

    const { storeId, itemId } = await oneItem(customer.token);
    const created = await place(customer.token, 'idem-food-queue-own', storeId, [{ itemId, quantity: 1 }]);
    expect(created.status).toBe(200);
    const orderId = created.body.data.id as string;

    const foods = app.get(FOOD_REPOSITORY);
    if (!(foods instanceof MemoryFoodRepository)) {
      throw new Error('Expected the in-memory food repository');
    }
    const otherStore = await foods.createStore(otherMerchant.userId, 'Cơm Tấm', [
      { name: 'Cơm sườn', priceVnd: 40_000 },
    ]);
    const foreignItem = otherStore.items[0];
    if (!foreignItem) {
      throw new Error('Expected a seeded menu item');
    }
    const foreign = await place(otherCustomer.token, 'idem-food-queue-other', otherStore.id, [
      { itemId: foreignItem.id, quantity: 1 },
    ]);
    expect(foreign.status).toBe(200);

    const listed = await request(app.getHttpServer())
      .get('/v1/food/orders/queue')
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    const rows = listed.body.data as { id: string; createdAt: string }[];
    const ids = rows.map((order) => order.id);
    expect(ids).toContain(orderId);
    expect(ids).not.toContain(foreign.body.data.id);
    const createdAts = rows.map((order) => order.createdAt);
    expect([...createdAts].sort()).toEqual(createdAts);
    const match = (listed.body.data as { id: string }[]).find((order) => order.id === orderId);
    expect(match).toEqual({
      id: orderId,
      storeId,
      status: 'PLACED',
      deliveryFareVnd: created.body.data.deliveryFareVnd,
      subtotalVnd: created.body.data.subtotalVnd,
      totalVnd: created.body.data.totalVnd,
      dropoff,
      lineCount: (created.body.data.lines as unknown[]).length,
      createdAt: expect.any(String),
      customerName: maskPersonName((await repository.findUserById(customer.userId))?.displayName),
      driverName: null,
    });
    expect(JSON.stringify(listed.body.data)).not.toContain('"phone"');
    expect(JSON.stringify(listed.body.data)).not.toContain(customer.userId);
  });

  it('summarises a merchant\'s own sales by Vietnam day with masked queue names', async () => {
    const customer = await login();
    const secondCustomer = await login();
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const owner = await login();
    await repository.insertGrant(owner.userId, 'MERCHANT', 'ACTIVE');
    await repository.updateUserProfile(secondCustomer.userId, { displayName: 'Trần Công Tiến' });
    await repository.updateUserProfile(driver.userId, { displayName: 'Lê Văn Bình' });
    const foods = app.get(FOOD_REPOSITORY);
    if (!(foods instanceof MemoryFoodRepository)) {
      throw new Error('Expected the in-memory food repository');
    }
    const store = await foods.createStore(owner.userId, 'Quán Thống Kê', [
      { name: 'Mì Quảng', priceVnd: 45_000 },
    ]);
    const item = store.items[0]!;

    const empty = await request(app.getHttpServer())
      .get('/v1/food/merchant/stats')
      .set('Authorization', `Bearer ${owner.token}`)
      .expect(200);
    expect(empty.body.data).toMatchObject({
      timezone: 'Asia/Ho_Chi_Minh',
      days: 7,
      today: { deliveredCount: 0, salesVnd: 0, openCount: 0 },
      topItems: [],
    });
    expect(empty.body.data.series).toHaveLength(7);

    const created = await place(customer.token, 'idem-food-stats-1', store.id, [
      { itemId: item.id, quantity: 2 },
    ]);
    const orderId = created.body.data.id as string;
    for (const step of ['accept', 'ready']) {
      await request(app.getHttpServer())
        .post(`/v1/food/orders/${orderId}/${step}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
    }
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/claim`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    const queue = await request(app.getHttpServer())
      .get('/v1/food/orders/queue')
      .set('Authorization', `Bearer ${owner.token}`)
      .expect(200);
    expect(queue.body.data[0]).toMatchObject({ id: orderId, driverName: 'Bình L.' });
    for (const step of ['pickup', 'deliver']) {
      const body = step === 'deliver' ? { deliveryCode: await deliveryCodeOf(customer.token, orderId) } : {};
      await request(app.getHttpServer())
        .post(`/v1/food/orders/${orderId}/${step}`)
        .set('Authorization', `Bearer ${driver.token}`)
        .send(body)
        .expect(200);
    }
    const open = await place(secondCustomer.token, 'idem-food-stats-2', store.id, [
      { itemId: item.id, quantity: 1 },
    ]);
    expect(open.status).toBe(200);
    const queue2 = await request(app.getHttpServer())
      .get('/v1/food/orders/queue')
      .set('Authorization', `Bearer ${owner.token}`)
      .expect(200);
    expect(queue2.body.data).toHaveLength(1);
    expect(queue2.body.data[0]).toMatchObject({ customerName: 'Tiến T.', driverName: null });

    const stats = await request(app.getHttpServer())
      .get('/v1/food/merchant/stats')
      .query({ days: 3 })
      .set('Authorization', `Bearer ${owner.token}`)
      .expect(200);
    const todayKey = new Date(Date.now() + 7 * 3_600_000).toISOString().slice(0, 10);
    expect(stats.body.data).toMatchObject({
      days: 3,
      today: { date: todayKey, deliveredCount: 1, salesVnd: 90_000, openCount: 1, cancelledCount: 0 },
      totals: { deliveredCount: 1, salesVnd: 90_000 },
      topItems: [{ name: 'Mì Quảng', quantity: 2 }],
    });
    expect(stats.body.data.series.map((d: { date: string }) => d.date).at(-1)).toBe(todayKey);
    expect(stats.body.data.series).toHaveLength(3);

    // Another merchant sees none of it; customers are refused.
    const other = await loginPhone('0901110001');
    const fixtureStats = await request(app.getHttpServer())
      .get('/v1/food/merchant/stats')
      .set('Authorization', `Bearer ${other.token}`)
      .expect(200);
    expect(fixtureStats.body.data.topItems.some((row: { name: string }) => row.name === 'Mì Quảng')).toBe(false);
    await request(app.getHttpServer())
      .get('/v1/food/merchant/stats')
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(403);
    await request(app.getHttpServer())
      .get('/v1/food/merchant/stats')
      .query({ days: 31 })
      .set('Authorization', `Bearer ${owner.token}`)
      .expect(400);
  });

  it('rejects a customer without a merchant grant from the food queue', async () => {
    const customer = await login();
    const { storeId, itemId } = await oneItem(customer.token);
    const placed = await place(customer.token, 'idem-food-queue-denied', storeId, [{ itemId, quantity: 1 }]);
    expect(placed.status).toBe(200);

    const denied = await request(app.getHttpServer())
      .get('/v1/food/orders/queue')
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(403);
    expect(denied.body.errorCode).toBe('ROLE_NOT_ACTIVE');
  });

  it('refuses cancel after the merchant has accepted', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const { storeId, itemId } = await oneItem(customer.token);
    const created = await place(customer.token, 'idem-food-cancel-1', storeId, [{ itemId, quantity: 1 }]);
    const orderId = created.body.data.id as string;

    const cancelled = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/cancel`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(cancelled.body.data.status).toBe('CANCELLED');
    expect(cancelled.body.data.cancelledBy).toBe('CUSTOMER');

    const again = await place(customer.token, 'idem-food-cancel-2', storeId, [{ itemId, quantity: 1 }]);
    expect(again.status).toBe(200);
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${again.body.data.id}/accept`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    const blocked = await request(app.getHttpServer())
      .post(`/v1/food/orders/${again.body.data.id}/cancel`)
      .set('Authorization', `Bearer ${customer.token}`);
    expect(blocked.status).toBe(409);
    expect(blocked.body.errorCode).toBe('FOOD_NOT_CANCELLABLE');
  });

  it('lets only the store owner reject a placed order', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const otherMerchant = await login();
    await repository.insertGrant(otherMerchant.userId, 'MERCHANT', 'ACTIVE');
    const { storeId, itemId } = await oneItem(customer.token);
    const created = await place(customer.token, 'idem-food-reject-1', storeId, [{ itemId, quantity: 1 }]);
    const orderId = created.body.data.id as string;

    const denied = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/reject`)
      .set('Authorization', `Bearer ${otherMerchant.token}`)
      .send({ reasonCode: 'OUT_OF_STOCK' });
    expect(denied.status).toBe(404);
    const asCustomer = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/reject`)
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ reasonCode: 'OUT_OF_STOCK' });
    expect(asCustomer.status).toBe(403);

    const noReason = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/reject`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({});
    expect(noReason.status).toBe(400);
    const otherWithoutNote = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/reject`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ reasonCode: 'OTHER', note: '   ' });
    expect(otherWithoutNote.status).toBe(400);
    expect(otherWithoutNote.body.errorCode).toBe('FOOD_REJECT_NOTE_REQUIRED');

    const rejected = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/reject`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ reasonCode: 'OUT_OF_STOCK', note: '  Hết bún bò hôm nay  ' })
      .expect(200);
    expect(rejected.body.data.status).toBe('CANCELLED');
    expect(rejected.body.data.cancelledBy).toBe('MERCHANT');
    expect(rejected.body.data.cancelReason).toEqual({
      code: 'OUT_OF_STOCK',
      note: 'Hết bún bò hôm nay',
    });
    const seen = await request(app.getHttpServer())
      .get(`/v1/food/orders/${orderId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(seen.body.data.cancelReason.code).toBe('OUT_OF_STOCK');

    const twice = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/reject`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ reasonCode: 'STORE_BUSY' });
    expect(twice.status).toBe(409);
    expect(twice.body.errorCode).toBe('FOOD_STATUS_CONFLICT');

    // The customer can order again right away.
    const again = await place(customer.token, 'idem-food-reject-2', storeId, [{ itemId, quantity: 1 }]);
    expect(again.status).toBe(200);
  });

  it('carries the store pickup point on the order for driver and Admin maps', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    await request(app.getHttpServer())
      .patch('/v1/food/merchant/store/location')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ lat: dropoff.lat, lng: dropoff.lng, addressLabel: '12 Bạch Đằng, Hải Châu' })
      .expect(200);
    const orderId = await claimReadyOrder(customer, merchant, driver, 'idem-food-pickup-point');
    const seen = await request(app.getHttpServer())
      .get(`/v1/food/orders/${orderId}`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    // Same point as the shared test dropoff so later fare assertions are unaffected.
    expect(seen.body.data.pickup).toEqual({
      lat: dropoff.lat,
      lng: dropoff.lng,
      label: '12 Bạch Đằng, Hải Châu',
    });

    // DEC-PROD-034: moving the store later does not move this order's pickup point.
    const moveStore = (lat: number, lng: number, addressLabel: string) =>
      request(app.getHttpServer())
        .patch('/v1/food/merchant/store/location')
        .set('Authorization', `Bearer ${merchant.token}`)
        .send({ lat, lng, addressLabel })
        .expect(200);
    await moveStore(dropoff.lat + 0.01, dropoff.lng + 0.01, 'Chi nhánh mới');
    try {
      const after = await request(app.getHttpServer())
        .get(`/v1/food/orders/${orderId}`)
        .set('Authorization', `Bearer ${driver.token}`)
        .expect(200);
      expect(after.body.data.pickup).toEqual(seen.body.data.pickup);
    } finally {
      await moveStore(dropoff.lat, dropoff.lng, '12 Bạch Đằng, Hải Châu');
    }
  });

  it('shares the courier location with the customer only while on the way (DEC-PROD-031)', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const orderId = await claimReadyOrder(customer, merchant, driver, 'idem-food-location');
    const locationOf = (token: string) =>
      request(app.getHttpServer())
        .get(`/v1/food/orders/${orderId}/driver-location`)
        .set('Authorization', `Bearer ${token}`);

    expect((await locationOf(customer.token).expect(200)).body.data).toEqual({ location: null });
    await request(app.getHttpServer())
      .post('/v1/me/presence/location')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ lat: 16.06, lng: 108.21 })
      .expect(200);
    const seen = await locationOf(customer.token).expect(200);
    expect(seen.body.data.location).toMatchObject({ lat: 16.06, lng: 108.21 });
    await locationOf(merchant.token).expect(404);

    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/pickup`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect((await locationOf(customer.token).expect(200)).body.data.location).not.toBeNull();
    const deliveryCode = await deliveryCodeOf(customer.token, orderId);
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/deliver`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ deliveryCode })
      .expect(200);
    expect((await locationOf(customer.token).expect(200)).body.data).toEqual({ location: null });
  });

  it('runs assigned → pickup → deliver for the assigned driver', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const orderId = await claimReadyOrder(
      customer,
      merchant,
      driver,
      'idem-food-lifecycle',
    );

    const picked = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/pickup`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(picked.body.data.status).toBe('PICKED_UP');
    expect(typeof picked.body.requestId).toBe('string');

    const deliveryCode = await deliveryCodeOf(customer.token, orderId);
    const delivered = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/deliver`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ deliveryCode })
      .expect(200);
    expect(delivered.body.data.status).toBe('DELIVERED');
    expect(Number.isInteger(delivered.body.data.totalVnd)).toBe(true);

    const journal = await request(app.getHttpServer())
      .get(`/v1/food/orders/${orderId}/ledger`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(journal.body.data.amountVnd).toBe(delivered.body.data.totalVnd);
    expect(journal.body.data.event).toBe('COD_OBLIGATION_POSTED');

    const again = await request(app.getHttpServer())
      .get(`/v1/food/orders/${orderId}/ledger`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    expect(again.body.data.id).toBe(journal.body.data.id);

    const ops = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    const opsList = await request(app.getHttpServer())
      .get('/v1/ops/food-orders?page=1&limit=5')
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(opsList.body.data.items.some((order: { id: string }) => order.id === orderId)).toBe(
      true,
    );

    const filteredByStatus = await request(app.getHttpServer())
      .get('/v1/ops/food-orders?page=1&limit=5&status=PLACED')
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(
      filteredByStatus.body.data.items.every(
        (o: { status: string }) => o.status === 'PLACED',
      ),
    ).toBe(true);

    const filteredByQ = await request(app.getHttpServer())
      .get(`/v1/ops/food-orders?page=1&limit=5&q=${orderId.slice(0, 8)}`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(
      filteredByQ.body.data.items.some((o: { id: string }) => o.id === orderId),
    ).toBe(true);
    await request(app.getHttpServer())
      .get(`/v1/ops/food-orders/${orderId}`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
  });

  it('lets the store owner manage catalog and denies another merchant', async () => {
    const owner = await login();
    await repository.insertGrant(owner.userId, 'MERCHANT', 'ACTIVE');
    const other = await login();
    await repository.insertGrant(other.userId, 'MERCHANT', 'ACTIVE');

    const catalog = await request(app.getHttpServer())
      .get('/v1/food/merchant/catalog')
      .set('Authorization', `Bearer ${owner.token}`)
      .expect(200);
    expect(catalog.body.data.ownerId).toBe(owner.userId);
    expect(catalog.body.data.sandboxSeed).toBe(false);

    const created = await request(app.getHttpServer())
      .post('/v1/food/merchant/items')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ name: 'Mì Quảng', priceVnd: 45_000 })
      .expect(200);
    expect(created.body.data.name).toBe('Mì Quảng');
    expect(created.body.data.available).toBe(true);
    const itemId = created.body.data.id as string;

    const updated = await request(app.getHttpServer())
      .patch(`/v1/food/merchant/items/${itemId}`)
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ priceVnd: 48_000 })
      .expect(200);
    expect(updated.body.data.priceVnd).toBe(48_000);

    const toggled = await request(app.getHttpServer())
      .patch(`/v1/food/merchant/items/${itemId}/availability`)
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ available: false })
      .expect(200);
    expect(toggled.body.data.available).toBe(false);

    const denied = await request(app.getHttpServer())
      .patch(`/v1/food/merchant/items/${itemId}/availability`)
      .set('Authorization', `Bearer ${other.token}`)
      .send({ available: true });
    expect(denied.status).toBe(403);
    expect(denied.body.errorCode).toBe('FOOD_NOT_STORE_OWNER');
  });

  it('persists ops catalog approve/reject and ignores client delivery fare', async () => {
    const owner = await login();
    await repository.insertGrant(owner.userId, 'MERCHANT', 'ACTIVE');
    const created = await request(app.getHttpServer())
      .post('/v1/food/merchant/items')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ name: 'Chè đậu', priceVnd: 20_000, available: false })
      .expect(200);
    const itemId = created.body.data.id as string;

    const ops = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);

    const rejected = await request(app.getHttpServer())
      .post(`/v1/ops/catalog/items/${itemId}/reject`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(201);
    expect(rejected.body.data).toMatchObject({
      success: true,
      id: itemId,
      available: false,
      moderationStatus: 'REJECTED',
    });

    const approved = await request(app.getHttpServer())
      .post(`/v1/ops/catalog/items/${itemId}/approve`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(201);
    expect(approved.body.data).toMatchObject({
      success: true,
      id: itemId,
      available: true,
      moderationStatus: 'APPROVED',
    });

    const listed = await request(app.getHttpServer())
      .get('/v1/ops/catalog/moderation')
      .query({ status: 'APPROVED' })
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .expect(200);
    expect(
      listed.body.data.items.some((row: { id: string }) => row.id === itemId),
    ).toBe(true);

    const customer = await login();
    const { storeId, itemId: lineItemId } = await oneItem(customer.token);
    const placed = await request(app.getHttpServer())
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'idem-food-fare-override')
      .send({
        storeId,
        items: [{ itemId: lineItemId, quantity: 1 }],
        dropoff,
        deliveryFareVnd: 99_000,
      })
      .expect(200);
    expect(placed.body.data.deliveryFareVnd).toBe(5_000);
  });

  it('forbids a non-assigned driver from pickup', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    const other = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    await repository.insertGrant(other.userId, 'DRIVER', 'ACTIVE');
    const orderId = await claimReadyOrder(customer, merchant, driver, 'idem-food-wrong-driver');

    const denied = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/pickup`)
      .set('Authorization', `Bearer ${other.token}`);
    expect(denied.status).toBe(403);
    expect(denied.body.errorCode).toBe('FOOD_NOT_ASSIGNED_DRIVER');
  });

  it('rejects an illegal food status transition with 409', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const orderId = await claimReadyOrder(customer, merchant, driver, 'idem-food-illegal');

    const skipped = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/deliver`)
      .set('Authorization', `Bearer ${driver.token}`);
    expect(skipped.status).toBe(409);
    expect(skipped.body.errorCode).toBe('FOOD_STATUS_CONFLICT');
  });

  it('gates delivery and handover on server-issued codes (DEC-PROD-036)', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const settings = app.get(PlatformSettingsService);
    await settings.patch('FOOD_HANDOVER_CODE_REQUIRED', 'true', 'test handover', 'ops-test');
    await settings.patch('FOOD_DELIVERY_CODE_MAX_ATTEMPTS', '2', 'test attempts', 'ops-test');
    try {
      const orderId = await claimReadyOrder(customer, merchant, driver, 'idem-food-codes');
      const read = (token: string) =>
        request(app.getHttpServer())
          .get(`/v1/food/orders/${orderId}`)
          .set('Authorization', `Bearer ${token}`)
          .expect(200);
      const post = (step: string, body: object) =>
        request(app.getHttpServer())
          .post(`/v1/food/orders/${orderId}/${step}`)
          .set('Authorization', `Bearer ${driver.token}`)
          .send(body);

      // Each code goes only to the party that hands it over.
      const merchantView = (await read(merchant.token)).body.data;
      expect(merchantView.handoverCode).toMatch(/^\d{4}$/);
      expect(merchantView).not.toHaveProperty('deliveryCode');
      const customerView = (await read(customer.token)).body.data;
      expect(customerView.deliveryCode).toMatch(/^\d{4}$/);
      expect(customerView).not.toHaveProperty('handoverCode');
      const driverView = (await read(driver.token)).body.data;
      expect(driverView).not.toHaveProperty('deliveryCode');
      expect(driverView).not.toHaveProperty('handoverCode');

      expect((await post('pickup', {})).body.errorCode).toBe('FOOD_HANDOVER_CODE_REQUIRED');
      await post('pickup', { handoverCode: 'abcd' }).expect(400);
      const wrongHandover = merchantView.handoverCode === '0000' ? '1111' : '0000';
      expect((await post('pickup', { handoverCode: wrongHandover })).body.errorCode).toBe(
        'FOOD_HANDOVER_CODE_INVALID',
      );
      expect((await post('pickup', { handoverCode: merchantView.handoverCode }).expect(200)).body.data.status).toBe(
        'PICKED_UP',
      );
      // After pickup the merchant no longer sees the handover code.
      expect((await read(merchant.token)).body.data).not.toHaveProperty('handoverCode');

      const code = (await read(customer.token)).body.data.deliveryCode as string;
      expect(code).toBe(customerView.deliveryCode);
      const wrong = code === '0000' ? '1111' : '0000';
      const missing = await post('deliver', {});
      expect(missing.status).toBe(422);
      expect(missing.body.errorCode).toBe('FOOD_DELIVERY_CODE_REQUIRED');
      expect((await post('deliver', { deliveryCode: wrong })).status).toBe(422);
      expect((await post('deliver', { deliveryCode: wrong })).body.errorCode).toBe('FOOD_DELIVERY_CODE_INVALID');
      // Attempts used up: even the right code is locked now.
      const locked = await post('deliver', { deliveryCode: code });
      expect(locked.status).toBe(423);
      expect(locked.body.errorCode).toBe('FOOD_DELIVERY_CODE_LOCKED');
    } finally {
      await settings.patch('FOOD_HANDOVER_CODE_REQUIRED', 'false', 'test reset', 'ops-test');
      await settings.patch('FOOD_DELIVERY_CODE_MAX_ATTEMPTS', '5', 'test reset', 'ops-test');
    }
  });

  it('delivers without a code when FOOD_DELIVERY_CODE_REQUIRED is false', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const settings = app.get(PlatformSettingsService);
    await settings.patch('FOOD_DELIVERY_CODE_REQUIRED', 'false', 'test off', 'ops-test');
    try {
      const orderId = await claimReadyOrder(customer, merchant, driver, 'idem-food-nocode');
      const view = await request(app.getHttpServer())
        .get(`/v1/food/orders/${orderId}`)
        .set('Authorization', `Bearer ${customer.token}`)
        .expect(200);
      expect(view.body.data).not.toHaveProperty('deliveryCode');
      for (const step of ['pickup', 'deliver']) {
        await request(app.getHttpServer())
          .post(`/v1/food/orders/${orderId}/${step}`)
          .set('Authorization', `Bearer ${driver.token}`)
          .expect(200);
      }
      await expect(settings.patch('FOOD_DELIVERY_CODE_REQUIRED', '"yes"', 'bad', 'ops-test')).rejects.toThrow();
    } finally {
      await settings.patch('FOOD_DELIVERY_CODE_REQUIRED', 'true', 'test reset', 'ops-test');
    }
  });

  it('refuses customer cancel after ASSIGNED', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const orderId = await claimReadyOrder(customer, merchant, driver, 'idem-food-cancel-assigned');

    const blocked = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/cancel`)
      .set('Authorization', `Bearer ${customer.token}`);
    expect(blocked.status).toBe(409);
    expect(blocked.body.errorCode).toBe('FOOD_NOT_CANCELLABLE');
  });

  it('lists customer order history and supports ops cancel + TEST_ONLY reassign', async () => {
    const customer = await login();
    // Fixture sandbox store owner phone (same as other merchant lifecycle tests).
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const orderId = await claimReadyOrder(customer, merchant, driver, 'idem-food-ops-intervene');

    const history = await request(app.getHttpServer())
      .get('/v1/food/orders?page=1&limit=10')
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(history.body.data.items.some((order: { id: string }) => order.id === orderId)).toBe(
      true,
    );

    const ops = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);

    const reassigned = await request(app.getHttpServer())
      .post(`/v1/ops/food-orders/${orderId}/reassign`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .send({ reason: 'TEST_ONLY return order to ready pool' })
      .expect(200);
    expect(reassigned.body.data.status).toBe('READY');
    expect(reassigned.body.data.assignedDriverId).toBeNull();

    const cancelled = await request(app.getHttpServer())
      .post(`/v1/ops/food-orders/${orderId}/cancel`)
      .set('Authorization', `Bearer ${ops.body.data.accessToken}`)
      .send({ reason: 'Merchant closed early — ops cancel' })
      .expect(200);
    expect(cancelled.body.data.status).toBe('CANCELLED');
    expect(cancelled.body.data.cancelledBy).toBe('OPS');
  });

  it('lets merchant set store location used by ready-list radius', async () => {
    const owner = await login();
    await repository.insertGrant(owner.userId, 'MERCHANT', 'ACTIVE');

    const updated = await request(app.getHttpServer())
      .patch('/v1/food/merchant/store/location')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ lat: 16.047079, lng: 108.20623 })
      .expect(200);
    expect(updated.body.data.lat).toBe(16.047079);
    expect(updated.body.data.lng).toBe(108.20623);
  });

  it('M030 renames the store and uploads, serves and removes its logo (DEC-PROD-045)', async () => {
    const owner = await login();
    await repository.insertGrant(owner.userId, 'MERCHANT', 'ACTIVE');
    const auth = { Authorization: `Bearer ${owner.token}` };
    const renamed = await request(app.getHttpServer())
      .patch('/v1/food/merchant/store/profile')
      .set(auth)
      .send({ name: '  Cơm   Gà Hội An  ' })
      .expect(200);
    expect(renamed.body.data.name).toBe('Cơm Gà Hội An');
    expect(renamed.body.data.logoUrl).toBeNull();
    await request(app.getHttpServer())
      .patch('/v1/food/merchant/store/profile')
      .set(auth)
      .send({ name: 'x' })
      .expect(400);

    const png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    const uploaded = await request(app.getHttpServer())
      .post('/v1/food/merchant/store/logo')
      .set(auth)
      .send({ dataUrl: `data:image/png;base64,${png}` })
      .expect(200);
    const logoUrl = uploaded.body.data.logoUrl as string;
    expect(logoUrl).toMatch(/^\/v1\/public\/store-logos\/[0-9a-f-]{36}\/[0-9a-f-]{36}\.png$/);
    const served = await request(app.getHttpServer()).get(logoUrl).expect(200);
    expect(served.headers['content-type']).toContain('image/png');
    await request(app.getHttpServer())
      .post('/v1/food/merchant/store/logo')
      .set(auth)
      .send({ dataUrl: 'data:application/pdf;base64,JVBERi0xLjQK' })
      .expect(415);

    const cleared = await request(app.getHttpServer())
      .delete('/v1/food/merchant/store/logo')
      .set(auth)
      .expect(200);
    expect(cleared.body.data.logoUrl).toBeNull();
    await request(app.getHttpServer()).get(logoUrl).expect(404);

    const stranger = await login();
    await request(app.getHttpServer())
      .patch('/v1/food/merchant/store/profile')
      .set('Authorization', `Bearer ${stranger.token}`)
      .send({ name: 'Không phải chủ' })
      .expect(403);
  });

  it('stores M024 busy/pause mode and blocks new orders while paused (DEC-PROD-026)', async () => {
    const owner = await login();
    await repository.insertGrant(owner.userId, 'MERCHANT', 'ACTIVE');
    const customer = await login();
    const foods = app.get(FOOD_REPOSITORY);
    if (!(foods instanceof MemoryFoodRepository)) {
      throw new Error('Expected the in-memory food repository');
    }
    const store = await foods.createStore(owner.userId, 'Bánh Mì Pause', [
      { name: 'Bánh mì thịt', priceVnd: 25_000 },
    ]);
    const itemId = store.items[0]!.id;
    const status = (body: object) =>
      request(app.getHttpServer())
        .patch('/v1/food/merchant/store/status')
        .set('Authorization', `Bearer ${owner.token}`)
        .send(body);

    const paused = await status({ mode: 'PAUSED', resumeAfterMinutes: 30 }).expect(200);
    expect(paused.body.data.serviceMode).toBe('PAUSED');
    const until = Date.parse(paused.body.data.serviceModeUntil as string);
    expect(until - Date.now()).toBeGreaterThan(29 * 60_000);
    expect(until - Date.now()).toBeLessThanOrEqual(30 * 60_000);

    const seen = await request(app.getHttpServer())
      .get(`/v1/food/stores/${store.id}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(seen.body.data.serviceMode).toBe('PAUSED');

    const blocked = await place(customer.token, 'idem-food-paused-1', store.id, [{ itemId, quantity: 1 }]);
    expect(blocked.status).toBe(409);
    expect(blocked.body.errorCode).toBe('FOOD_STORE_PAUSED');

    const busy = await status({ mode: 'BUSY' }).expect(200);
    expect(busy.body.data).toMatchObject({ serviceMode: 'BUSY', serviceModeUntil: null });
    const accepted = await place(customer.token, 'idem-food-paused-2', store.id, [{ itemId, quantity: 1 }]);
    expect(accepted.status).toBe(200);

    const reopened = await status({ mode: 'OPEN', resumeAfterMinutes: 60 }).expect(200);
    expect(reopened.body.data).toMatchObject({ serviceMode: 'OPEN', serviceModeUntil: null });

    await status({ mode: 'CLOSED' }).expect(400);
    await status({ mode: 'PAUSED', resumeAfterMinutes: 45 }).expect(400);
    await request(app.getHttpServer())
      .patch('/v1/food/merchant/store/status')
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ mode: 'PAUSED' })
      .expect(403);
  });

  it('enforces M023 hours/closed days and lists closed stores last (DEC-PROD-027)', async () => {
    const owner = await login();
    await repository.insertGrant(owner.userId, 'MERCHANT', 'ACTIVE');
    const customer = await login();
    const foods = app.get(FOOD_REPOSITORY);
    if (!(foods instanceof MemoryFoodRepository)) {
      throw new Error('Expected the in-memory food repository');
    }
    const store = await foods.createStore(owner.userId, 'Aaa Giờ Mở Cửa', [
      { name: 'Cơm gà', priceVnd: 35_000 },
    ]);
    const itemId = store.items[0]!.id;
    const today = vnClock(new Date());
    const hours = (body: object) =>
      request(app.getHttpServer())
        .put('/v1/food/merchant/store/hours')
        .set('Authorization', `Bearer ${owner.token}`)
        .send(body);
    const allDays = [1, 2, 3, 4, 5, 6, 7];

    // Every weekday except today → closed now.
    const closed = await hours({
      weekly: allDays
        .filter((weekday) => weekday !== today.weekday)
        .map((weekday) => ({ weekday, opensAt: '00:00', closesAt: '24:00' })),
      closures: [{ date: '2027-01-01', note: 'Nghỉ Tết dương lịch' }],
      lastOrderMinutes: 15,
    }).expect(200);
    expect(closed.body.data).toMatchObject({ openNow: false, closedReason: 'CLOSED' });
    expect(closed.body.data.schedule).toMatchObject({
      hoursConfigured: true,
      lastOrderMinutes: 15,
      closures: [{ date: '2027-01-01', note: 'Nghỉ Tết dương lịch' }],
    });
    expect(closed.body.data.schedule.weekly).toHaveLength(6);

    const blocked = await place(customer.token, 'idem-food-hours-1', store.id, [{ itemId, quantity: 1 }]);
    expect(blocked.status).toBe(409);
    expect(blocked.body.errorCode).toBe('FOOD_STORE_CLOSED');

    const list = await request(app.getHttpServer())
      .get('/v1/food/stores')
      .query({ sort_by: 'name', limit: 100 })
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    const listed = list.body.data.items as { id: string; openNow: boolean; closedReason: string | null }[];
    const index = listed.findIndex((entry) => entry.id === store.id);
    expect(listed[index]).toMatchObject({ openNow: false, closedReason: 'CLOSED' });
    // Sorted by name it would be first; closed stores go after every open one.
    expect(listed.slice(0, index).every((entry) => entry.openNow)).toBe(true);

    // Ops directory (Admin) sees the same availability.
    expect(await foods.findStoreForOps(store.id)).toMatchObject({
      serviceMode: 'OPEN',
      openNow: false,
      closedReason: 'CLOSED',
    });

    // A special closed day wins over open hours.
    const holiday = await hours({
      weekly: allDays.map((weekday) => ({ weekday, opensAt: '00:00', closesAt: '24:00' })),
      closures: [{ date: today.date }],
      lastOrderMinutes: 0,
    }).expect(200);
    expect(holiday.body.data.openNow).toBe(false);

    const open = await hours({
      weekly: allDays.map((weekday) => ({ weekday, opensAt: '00:00', closesAt: '24:00' })),
      closures: [],
      lastOrderMinutes: 0,
    }).expect(200);
    expect(open.body.data).toMatchObject({ openNow: true, closedReason: null });
    const accepted = await place(customer.token, 'idem-food-hours-2', store.id, [{ itemId, quantity: 1 }]);
    expect(accepted.status).toBe(200);

    const bad = await hours({
      weekly: [{ weekday: 1, opensAt: '07:00', closesAt: '07:00' }],
      closures: [],
      lastOrderMinutes: 0,
    });
    expect(bad.status).toBe(400);
    expect(bad.body.errorCode).toBe('FOOD_HOURS_INVALID');
    await hours({ weekly: [], closures: [], lastOrderMinutes: 20 }).expect(400);
    await hours({ weekly: [{ weekday: 8, opensAt: '07:00', closesAt: '22:00' }], closures: [], lastOrderMinutes: 0 }).expect(400);
  });

  it('applies M022 accept settings and BUSY extra prep at placement (DEC-PROD-028)', async () => {
    const owner = await login();
    await repository.insertGrant(owner.userId, 'MERCHANT', 'ACTIVE');
    const foods = app.get(FOOD_REPOSITORY);
    if (!(foods instanceof MemoryFoodRepository)) {
      throw new Error('Expected the in-memory food repository');
    }
    const store = await foods.createStore(owner.userId, 'Quán Nhận Đơn', [
      { name: 'Bún chả', priceVnd: 45_000 },
    ]);
    const itemId = store.items[0]!.id;
    const settings = (body: object) =>
      request(app.getHttpServer())
        .put('/v1/food/merchant/store/accept-settings')
        .set('Authorization', `Bearer ${owner.token}`)
        .send(body);

    const saved = await settings({
      acceptMode: 'AUTO',
      maxActiveOrders: 1,
      defaultPrepMinutes: 20,
      lastOrderMinutes: 15,
    }).expect(200);
    expect(saved.body.data).toMatchObject({
      acceptSettings: { acceptMode: 'AUTO', maxActiveOrders: 1, defaultPrepMinutes: 20, busyExtraMinutes: 15 },
      estimatedPrepMinutes: 20,
      schedule: { lastOrderMinutes: 15 },
    });

    // BUSY with a merchant-set extra stretches the estimate customers see.
    const busy = await request(app.getHttpServer())
      .patch('/v1/food/merchant/store/status')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ mode: 'BUSY', busyExtraMinutes: 30 })
      .expect(200);
    expect(busy.body.data).toMatchObject({ serviceMode: 'BUSY', estimatedPrepMinutes: 50 });

    const first = await login();
    const detail = await request(app.getHttpServer())
      .get(`/v1/food/stores/${store.id}`)
      .set('Authorization', `Bearer ${first.token}`)
      .expect(200);
    expect(detail.body.data.estimatedPrepMinutes).toBe(50);
    expect(detail.body.data).not.toHaveProperty('acceptSettings');

    const before = Date.now();
    const auto = await place(first.token, 'idem-food-accept-1', store.id, [{ itemId, quantity: 1 }]);
    expect(auto.status).toBe(200);
    expect(auto.body.data).toMatchObject({ status: 'PREPARING', prepMinutes: 50 });
    const readyAt = Date.parse(auto.body.data.estimatedReadyAt as string);
    expect(readyAt - before).toBeGreaterThanOrEqual(50 * 60_000 - 1_000);
    expect(readyAt - before).toBeLessThanOrEqual(50 * 60_000 + 5_000);

    // Cap of one: the second customer is turned away while the first is cooking.
    const second = await login();
    const full = await place(second.token, 'idem-food-accept-2', store.id, [{ itemId, quantity: 1 }]);
    expect(full.status).toBe(409);
    expect(full.body.errorCode).toBe('FOOD_STORE_AT_CAPACITY');

    // Ready frees the slot; MANUAL keeps new orders in PLACED.
    await request(app.getHttpServer())
      .post(`/v1/food/orders/${auto.body.data.id as string}/ready`)
      .set('Authorization', `Bearer ${owner.token}`)
      .expect(200);
    await settings({ acceptMode: 'MANUAL', maxActiveOrders: null, defaultPrepMinutes: 10, lastOrderMinutes: 0 }).expect(200);
    const manual = await place(second.token, 'idem-food-accept-3', store.id, [{ itemId, quantity: 1 }]);
    expect(manual.status).toBe(200);
    expect(manual.body.data).toMatchObject({ status: 'PLACED', prepMinutes: 40 });

    expect(await foods.findStoreForOps(store.id)).toMatchObject({
      acceptSettings: { acceptMode: 'MANUAL', maxActiveOrders: null, defaultPrepMinutes: 10, busyExtraMinutes: 30 },
      estimatedPrepMinutes: 40,
    });

    await settings({ acceptMode: 'SOMETIMES', maxActiveOrders: null, defaultPrepMinutes: 10, lastOrderMinutes: 0 }).expect(400);
    await settings({ acceptMode: 'AUTO', maxActiveOrders: 0, defaultPrepMinutes: 10, lastOrderMinutes: 0 }).expect(400);
    await settings({ acceptMode: 'AUTO', maxActiveOrders: 5, defaultPrepMinutes: 200, lastOrderMinutes: 0 }).expect(400);
    await settings({ acceptMode: 'AUTO', maxActiveOrders: 5, defaultPrepMinutes: 20, lastOrderMinutes: 7 }).expect(400);
    await request(app.getHttpServer())
      .patch('/v1/food/merchant/store/status')
      .set('Authorization', `Bearer ${owner.token}`)
      .send({ mode: 'BUSY', busyExtraMinutes: 7 })
      .expect(400);
  });

  it('books only DealGo\'s share of a voucher by campaign sponsor', async () => {
    const promotions = app.get<PromotionRepository>(PROMOTION_REPOSITORY);
    const ledger = app.get<LedgerRepository>(LEDGER_REPOSITORY);
    const now = Date.now();
    for (const [code, sponsor] of [
      ['SHARE10K', 'SHARED'],
      ['MERCH10K', 'MERCHANT'],
    ] as const) {
      await promotions.create({
        code,
        name: code,
        description: code,
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
        sponsor,
      } as never);
    }
    await app
      .get(PlatformSettingsService)
      .patch('VOUCHER_SHARED_PLATFORM_PERCENT', '30', 'test split', 'ops-test');
    const merchant = await loginPhone('0901110001');
    const driver = await login();
    await repository.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const funded: Record<string, number | null> = {};
    for (const code of ['SHARE10K', 'MERCH10K']) {
      const customer = await login();
      const { storeId, itemId } = await oneItem(customer.token);
      const placed = await request(app.getHttpServer())
        .post('/v1/food/orders')
        .set('Authorization', `Bearer ${customer.token}`)
        .set('Idempotency-Key', `sponsor-${code}`)
        .send({ storeId, items: [{ itemId, quantity: 1 }], dropoff, voucherCode: code })
        .expect(200);
      expect(placed.body.data.discountVnd).toBe(10_000);
      expect(placed.body.data).not.toHaveProperty('voucherSponsor');
      const orderId = placed.body.data.id as string;
      for (const [actor, step] of [
        [merchant, 'accept'],
        [merchant, 'ready'],
        [driver, 'claim'],
        [driver, 'pickup'],
        [driver, 'deliver'],
      ] as const) {
        const body = step === 'deliver' ? { deliveryCode: await deliveryCodeOf(customer.token, orderId) } : {};
        await request(app.getHttpServer())
          .post(`/v1/food/orders/${orderId}/${step}`)
          .set('Authorization', `Bearer ${actor.token}`)
          .send(body)
          .expect(200);
      }
      const journal = await ledger.findByEntity('FOOD_ORDER', orderId, 'PROMOTION_DISCOUNT_FUNDED');
      funded[code] = journal?.amountVnd ?? null;
    }
    expect(funded).toEqual({ SHARE10K: 3000, MERCH10K: null });
    await app
      .get(PlatformSettingsService)
      .patch('VOUCHER_SHARED_PLATFORM_PERCENT', '100', 'test reset', 'ops-test');
  });

  it('prices item options server-side and snapshots them on order lines (DEC-PROD-033)', async () => {
    const merchant = await loginPhone('0901110001');
    const other = await login();
    await repository.insertGrant(other.userId, 'MERCHANT', 'ACTIVE');
    const customer = await login();
    const server = app.getHttpServer();
    const created = await request(server)
      .post('/v1/food/merchant/items')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ name: 'Trà sữa thử tuỳ chọn', priceVnd: 30_000 })
      .expect(200);
    const itemId = created.body.data.id as string;
    expect(created.body.data.optionGroups).toEqual([]);

    const layout = {
      groups: [
        {
          name: 'Size',
          minSelect: 1,
          maxSelect: 1,
          options: [
            { name: 'M', priceDeltaVnd: 0 },
            { name: 'L', priceDeltaVnd: 8_000 },
          ],
        },
        {
          name: 'Topping',
          minSelect: 0,
          maxSelect: 2,
          options: [
            { name: 'Trân châu', priceDeltaVnd: 5_000 },
            { name: 'Thạch', priceDeltaVnd: 4_000 },
            { name: 'Trứng', priceDeltaVnd: 6_000, available: false },
          ],
        },
      ],
    };
    const saved = await request(server)
      .put(`/v1/food/merchant/items/${itemId}/options`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .send(layout)
      .expect(200);
    const [size, topping] = saved.body.data.optionGroups as Array<{
      id: string;
      options: Array<{ id: string; name: string }>;
    }>;
    const opt = (group: typeof size, name: string) =>
      group.options.find((option) => option.name === name)!.id;

    const bad = await request(server)
      .put(`/v1/food/merchant/items/${itemId}/options`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ groups: [{ ...layout.groups[0], minSelect: 2, maxSelect: 1 }] });
    expect(bad.status).toBe(400);
    expect(bad.body.errorCode).toBe('FOOD_OPTIONS_INVALID');
    const foreign = await request(server)
      .put(`/v1/food/merchant/items/${itemId}/options`)
      .set('Authorization', `Bearer ${other.token}`)
      .send(layout);
    expect(foreign.status).toBe(403);

    const storeId = (
      await request(server)
        .get('/v1/food/merchant/catalog')
        .set('Authorization', `Bearer ${merchant.token}`)
        .expect(200)
    ).body.data.id as string;
    const detail = await request(server)
      .get(`/v1/food/stores/${storeId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    const listed = (detail.body.data.items as Array<{ id: string; optionGroups: unknown[] }>).find(
      (item) => item.id === itemId,
    );
    expect(listed?.optionGroups).toHaveLength(2);

    for (const optionIds of [[], [opt(size, 'M'), opt(topping, 'Trứng')], [opt(size, 'M'), opt(size, 'L')]]) {
      const rejected = await place(customer.token, `idem-opt-bad-${optionIds.length}-${optionIds[1] ?? ''}`, storeId, [
        { itemId, quantity: 1, optionIds },
      ]);
      expect(rejected.status).toBe(409);
      expect(rejected.body.errorCode).toBe('FOOD_OPTION_INVALID');
    }

    const placed = await place(customer.token, 'idem-opt-ok', storeId, [
      { itemId, quantity: 2, optionIds: [opt(topping, 'Trân châu'), opt(size, 'L')] },
      { itemId, quantity: 1, optionIds: [opt(size, 'M')] },
    ]).expect(200);
    // (30 000 + 8 000 + 5 000) × 2 + 30 000 × 1, computed by the server.
    expect(placed.body.data.subtotalVnd).toBe(116_000);
    const lines = placed.body.data.lines as Array<{
      unitPriceVnd: number;
      options: Array<{ groupName: string; name: string; priceDeltaVnd: number }>;
    }>;
    expect(lines[0].unitPriceVnd).toBe(43_000);
    expect(lines[0].options.map((o) => `${o.groupName}:${o.name}:${o.priceDeltaVnd}`)).toEqual([
      'Size:L:8000',
      'Topping:Trân châu:5000',
    ]);
    expect(lines[1].options.map((o) => o.name)).toEqual(['M']);

    // Renaming keeps ids; the placed order keeps what the customer chose.
    const renamed = await request(server)
      .put(`/v1/food/merchant/items/${itemId}/options`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({
        groups: [
          {
            id: size.id,
            name: 'Size',
            minSelect: 1,
            maxSelect: 1,
            options: [
              { id: opt(size, 'M'), name: 'M', priceDeltaVnd: 0 },
              { id: opt(size, 'L'), name: 'L lớn', priceDeltaVnd: 10_000 },
            ],
          },
        ],
      })
      .expect(200);
    expect(renamed.body.data.optionGroups[0].id).toBe(size.id);
    expect(renamed.body.data.optionGroups[0].options[1].id).toBe(opt(size, 'L'));
    const reread = await request(server)
      .get(`/v1/food/orders/${placed.body.data.id}`)
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    expect(reread.body.data.lines[0].options[0].name).toBe('L');
    expect(reread.body.data.lines[0].unitPriceVnd).toBe(43_000);
    await request(server)
      .post(`/v1/food/orders/${placed.body.data.id}/cancel`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
  });

  /** DEC-PROD-036: the customer reads the delivery code from the order while it is on the way. */
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
