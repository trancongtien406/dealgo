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
import { CatalogModule } from '../../../src/modules/catalog/catalog.module.js';
import { FOOD_REPOSITORY } from '../../../src/modules/food-order/food.constants.js';
import { FoodModule } from '../../../src/modules/food-order/food.module.js';
import { MemoryFoodRepository } from '../../../src/modules/food-order/food.repository.js';

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
      status: 'READY',
      deliveryFareVnd: ready.body.data.deliveryFareVnd,
      subtotalVnd: ready.body.data.subtotalVnd,
      totalVnd: ready.body.data.totalVnd,
      dropoff,
      lineCount: (ready.body.data.lines as unknown[]).length,
      store: null,
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
    });
    expect(JSON.stringify(listed.body.data)).not.toContain('"phone"');
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

    const delivered = await request(app.getHttpServer())
      .post(`/v1/food/orders/${orderId}/deliver`)
      .set('Authorization', `Bearer ${driver.token}`)
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
    items: { itemId: string; quantity: number }[],
  ) {
    return request(app.getHttpServer())
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idempotencyKey)
      .send({ storeId, items, dropoff, deliveryFareVnd: 15_000 });
  }
});
