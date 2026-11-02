/**
 * Merchant order change against Postgres: the merchant trims an order (hết món, GrabFood/ShopeeFood style),
 * the customer accepts / rejects, or the change expires (FOOD_ORDER_CHANGE_RESPONSE_MINUTES).
 * Checks totals, food_order_changes rows, outbox rows and that two concurrent responses settle once.
 * Skips when DATABASE_URL is unset.
 */
import { randomUUID } from 'node:crypto';
import { uniqueTestPhone } from './test-phone.js';
import { approveStoreItems, pinStore } from './store-pin.js';
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

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;
const RUN = `pgc-${Date.now()}-${randomUUID().slice(0, 6)}`;
const dropoff = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };

type Actor = { token: string; userId: string };

describePg('food merchant order change (postgres)', () => {
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



  async function twoLineOrder(tag: string) {
    const { merchant, storeId, itemId } = await merchantWithItem(`${tag} Bún`);
    const drink = await post(merchant.token, '/v1/food/merchant/items', { name: `${tag} Trà ${RUN}`, priceVnd: 10_000 }).expect(200);
    await approveStoreItems(app, merchant.token);
    const customer = await login();
    const placed = await http()
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `${RUN}-${tag}`)
      .send({
        storeId,
        dropoff,
        deliveryFareVnd: 15_000,
        items: [
          { itemId, quantity: 2 },
          { itemId: drink.body.data.id, quantity: 1 },
        ],
      });
    if (placed.status !== 200) throw new Error(`place ${placed.status}: ${JSON.stringify(placed.body)}`);
    const order = placed.body.data as { id: string; subtotalVnd: number; lines: { id: string; itemId: string; quantity: number }[] };
    const main = order.lines.find((l) => l.itemId === itemId)!;
    const tea = order.lines.find((l) => l.itemId !== itemId)!;
    return { merchant, customer, order, main, tea };
  }

  it('accept: lines + totals change in one transaction, outbox has PENDING + ACCEPTED, ready unblocked', async () => {
    const { merchant, customer, order, main, tea } = await twoLineOrder('acc');
    expect(order.subtotalVnd).toBe(100_000);
    await post(merchant.token, `/v1/food/orders/${order.id}/accept`).expect(200);
    const proposed = await post(merchant.token, `/v1/food/orders/${order.id}/changes`, {
      reasonCode: 'NOT_ENOUGH_PORTIONS',
      lines: [
        { lineId: main.id, toQuantity: 1 },
        { lineId: tea.id, toQuantity: 0 },
      ],
    }).expect(201);
    const change = proposed.body.data.change as { id: string; newSubtotalVnd: number };
    expect(change.newSubtotalVnd).toBe(45_000);
    // One pending change at a time; ready is blocked until the customer answers.
    expect((await post(merchant.token, `/v1/food/orders/${order.id}/changes`, { reasonCode: 'OUT_OF_STOCK', lines: [{ lineId: main.id, toQuantity: 0 }] })).status).toBe(409);
    expect((await post(merchant.token, `/v1/food/orders/${order.id}/ready`)).status).toBe(409);

    // Two taps at once: exactly one wins.
    const results = await Promise.all([
      post(customer.token, `/v1/food/orders/${order.id}/changes/${change.id}/accept`),
      post(customer.token, `/v1/food/orders/${order.id}/changes/${change.id}/accept`),
    ]);
    expect(results.map((r) => r.status).sort((a, b) => a - b)).toEqual([200, 409]);

    const db = prisma.db()!;
    const row = await db.foodOrder.findUniqueOrThrow({ where: { id: order.id }, include: { lines: true } });
    expect(row.subtotalVnd).toBe(45_000);
    expect(row.totalVnd).toBe(45_000 + row.deliveryFareVnd - row.discountVnd);
    expect(row.lines).toHaveLength(1);
    expect(row.lines[0]).toMatchObject({ id: main.id, quantity: 1 });
    expect((await db.foodOrderChange.findUniqueOrThrow({ where: { id: change.id } })).status).toBe('ACCEPTED');
    const outbox = await db.outboxMessage.findMany({ where: { eventKey: { startsWith: `FoodOrder:${order.id}:change:` } } });
    expect(outbox.map((e: { eventType: string }) => e.eventType).sort()).toEqual(['FoodOrder.change.ACCEPTED', 'FoodOrder.change.PENDING']);
    await post(merchant.token, `/v1/food/orders/${order.id}/ready`).expect(200);
  });

  it('reject: order CANCELLED (CUSTOMER, CHANGE_REJECTED), no further changes', async () => {
    const { merchant, customer, order, tea } = await twoLineOrder('rej');
    const proposed = await post(merchant.token, `/v1/food/orders/${order.id}/changes`, {
      reasonCode: 'OUT_OF_STOCK',
      lines: [{ lineId: tea.id, toQuantity: 0 }],
    }).expect(201);
    const changeId = proposed.body.data.change.id as string;
    const rejected = await post(customer.token, `/v1/food/orders/${order.id}/changes/${changeId}/reject`).expect(200);
    expect(rejected.body.data.order.status).toBe('CANCELLED');
    const db = prisma.db()!;
    const row = await db.foodOrder.findUniqueOrThrow({ where: { id: order.id } });
    expect(row.status).toBe('CANCELLED');
    expect(row.subtotalVnd).toBe(100_000);
    expect((await db.foodOrderChange.findUniqueOrThrow({ where: { id: changeId } })).status).toBe('REJECTED');
    expect((await post(customer.token, `/v1/food/orders/${order.id}/changes/${changeId}/accept`)).status).toBeGreaterThanOrEqual(400);
  });

  it('expiry: timeoutDue cancels as SYSTEM (CHANGE_EXPIRED) once the response window passes', async () => {
    const { merchant, customer, order, tea } = await twoLineOrder('exp');
    const proposed = await post(merchant.token, `/v1/food/orders/${order.id}/changes`, {
      reasonCode: 'OTHER',
      note: 'Hết đá',
      lines: [{ lineId: tea.id, toQuantity: 0 }],
    }).expect(201);
    const changeId = proposed.body.data.change.id as string;
    const later = new Date(Date.now() + 60 * 60_000);
    // Customer answering after the deadline is refused, the sweep closes it.
    await app.get(FoodService).timeoutDue(later);
    const db = prisma.db()!;
    expect((await db.foodOrderChange.findUniqueOrThrow({ where: { id: changeId } })).status).toBe('EXPIRED');
    const row = await db.foodOrder.findUniqueOrThrow({ where: { id: order.id } });
    expect(row.status).toBe('CANCELLED');
    expect((await post(customer.token, `/v1/food/orders/${order.id}/changes/${changeId}/accept`)).status).toBeGreaterThanOrEqual(400);
  });
});
