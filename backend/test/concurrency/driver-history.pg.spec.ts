import { seedDriverClass } from './driver-class.js';
/**
 * Driver history Prisma queries against Postgres (delivered food order → history + summary).
 * Skips when DATABASE_URL is unset (default unit suite uses memory repos).
 */
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
import { PlatformSettingsService } from '../../src/platform/settings/platform-settings.service.js';
import { DriverHistoryModule } from '../../src/modules/driver-history/driver-history.module.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

const dropoff = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };

describePg('driver history (postgres)', () => {
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
        DriverHistoryModule,
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

  function post(token: string, path: string) {
    return request(app.getHttpServer()).post(path).set('Authorization', `Bearer ${token}`);
  }

  function get(token: string, path: string) {
    return request(app.getHttpServer()).get(path).set('Authorization', `Bearer ${token}`);
  }

  it('lists a delivered order with its fare, rating and today summary', async () => {
    const merchant = await login();
    await ensureGrant(app.get(IDENTITY_REPOSITORY), merchant.userId, 'MERCHANT');
    await get(merchant.token, '/v1/food/merchant/catalog').expect(200);
    const item = await post(merchant.token, '/v1/food/merchant/items')
      .send({ name: `History Bun ${Date.now()}`, priceVnd: 60_000 })
      .expect(200);
    const catalog = await get(merchant.token, '/v1/food/merchant/catalog').expect(200);
    await pinStore(app, merchant.token);
    const customer = await login();
    const driver = await login();
    await ensureGrant(app.get(IDENTITY_REPOSITORY), driver.userId, 'DRIVER');
    await seedDriverClass(app, driver.userId);

    await get(customer.token, '/v1/driver/history').expect(403);
    const empty = await get(driver.token, '/v1/driver/history').expect(200);
    expect(empty.body.data).toEqual({ items: [], nextCursor: null });

    const settings = app.get(PlatformSettingsService);
    await settings.patch('FOOD_DRIVER_COMMISSION_PERCENT', '12.5', 'pg test TEST_ONLY', driver.userId);

    const placed = await post(customer.token, '/v1/food/orders')
      .set('Idempotency-Key', `hist-${Date.now()}`)
      .send({
        storeId: catalog.body.data.id,
        dropoff,
        items: [{ itemId: item.body.data.id, quantity: 1 }],
      })
      .expect(200);
    const orderId = placed.body.data.id as string;
    await post(merchant.token, `/v1/food/orders/${orderId}/accept`).expect(200);
    await post(merchant.token, `/v1/food/orders/${orderId}/ready`).expect(200);
    await post(driver.token, `/v1/food/orders/${orderId}/claim`).expect(200);
    await post(driver.token, `/v1/food/orders/${orderId}/pickup`).expect(200);
    // DEC-PROD-036: the customer's delivery code (FOOD_DELIVERY_CODE_REQUIRED defaults to true).
    const deliveryCode = (await get(customer.token, `/v1/food/orders/${orderId}`).expect(200)).body.data
      .deliveryCode as string;
    await post(driver.token, `/v1/food/orders/${orderId}/deliver`).send({ deliveryCode }).expect(200);
    // Later rate changes must not rewrite this delivery's earnings.
    await settings.patch('FOOD_DRIVER_COMMISSION_PERCENT', '30', 'pg test TEST_ONLY', driver.userId);
    const fare = placed.body.data.deliveryFareVnd as number;
    const fee = Math.round((fare * 1250) / 10_000);
    const db = prisma.db()!;
    const snapshot = await db.jobEarning.findUniqueOrThrow({
      where: { entityType_entityId: { entityType: 'FOOD_ORDER', entityId: orderId } },
    });
    expect(snapshot).toMatchObject({ feeBps: 1250, feeVnd: fee, netVnd: fare - fee });
    const journal = await db.ledgerJournal.findFirstOrThrow({
      where: { entityId: orderId, event: 'DRIVER_PLATFORM_FEE_ACCRUED' },
    });
    expect(journal.amountVnd).toBe(fee);
    await post(customer.token, '/v1/ratings')
      .send({ subjectType: 'FOOD_ORDER', subjectId: orderId, driverStars: 4, storeStars: 5 })
      .expect(200);

    const history = await get(driver.token, '/v1/driver/history?limit=5').expect(200);
    expect(history.body.data.items).toHaveLength(1);
    expect(history.body.data.items[0]).toMatchObject({
      kind: 'FOOD_ORDER',
      id: orderId,
      outcome: 'COMPLETED',
      fareVnd: fare,
      feePercent: 12.5,
      feeVnd: fee,
      earningsVnd: fare - fee,
      driverStars: 4,
    });
    const rides = await get(driver.token, '/v1/driver/history?kind=RIDE').expect(200);
    expect(rides.body.data.items).toEqual([]);

    const summary = await get(driver.token, '/v1/driver/history/summary').expect(200);
    expect(summary.body.data.today.completedJobs).toBe(1);
    expect(summary.body.data.today).toMatchObject({
      grossVnd: fare,
      feeVnd: fee,
      earningsVnd: fare - fee,
    });
    await settings.patch('FOOD_DRIVER_COMMISSION_PERCENT', '0', 'pg test reset', driver.userId);
    expect(summary.body.data.days).toHaveLength(7);
    expect(summary.body.data.rating).toMatchObject({ average: 4, count: 1 });
  });

  it('rolls the delivery back when the fee journal cannot be written', async () => {
    const merchant = await login();
    await ensureGrant(app.get(IDENTITY_REPOSITORY), merchant.userId, 'MERCHANT');
    await get(merchant.token, '/v1/food/merchant/catalog').expect(200);
    const item = await post(merchant.token, '/v1/food/merchant/items')
      .send({ name: `Atomic Mi ${Date.now()}`, priceVnd: 40_000 })
      .expect(200);
    const catalog = await get(merchant.token, '/v1/food/merchant/catalog').expect(200);
    await pinStore(app, merchant.token);
    const customer = await login();
    const driver = await login();
    await ensureGrant(app.get(IDENTITY_REPOSITORY), driver.userId, 'DRIVER');
    await seedDriverClass(app, driver.userId);
    const settings = app.get(PlatformSettingsService);
    await settings.patch('FOOD_DRIVER_COMMISSION_PERCENT', '10', 'pg test TEST_ONLY', driver.userId);

    const placed = await post(customer.token, '/v1/food/orders')
      .set('Idempotency-Key', `atomic-${Date.now()}`)
      .send({
        storeId: catalog.body.data.id,
        dropoff,
        items: [{ itemId: item.body.data.id, quantity: 1 }],
      })
      .expect(200);
    const orderId = placed.body.data.id as string;
    await post(merchant.token, `/v1/food/orders/${orderId}/accept`).expect(200);
    await post(merchant.token, `/v1/food/orders/${orderId}/ready`).expect(200);
    await post(driver.token, `/v1/food/orders/${orderId}/claim`).expect(200);
    await post(driver.token, `/v1/food/orders/${orderId}/pickup`).expect(200);
    const deliveryCode = (await get(customer.token, `/v1/food/orders/${orderId}`).expect(200)).body.data
      .deliveryCode as string;

    const db = prisma.db()!;
    const revenue = 'sandbox.fee.platform_revenue';
    // Hide the revenue account so the fee journal fails inside the delivery transaction.
    await db.ledgerAccount.update({ where: { code: revenue }, data: { code: `${revenue}.hidden` } });
    try {
      const failed = await post(driver.token, `/v1/food/orders/${orderId}/deliver`).send({ deliveryCode });
      expect(failed.status).toBeGreaterThanOrEqual(400);
      const order = await db.foodOrder.findUniqueOrThrow({ where: { id: orderId } });
      expect(order.status).toBe('PICKED_UP');
      expect(
        await db.jobEarning.count({ where: { entityType: 'FOOD_ORDER', entityId: orderId } }),
      ).toBe(0);
      expect(await db.ledgerJournal.count({ where: { entityId: orderId } })).toBe(0);
    } finally {
      await db.ledgerAccount.update({
        where: { code: `${revenue}.hidden` },
        data: { code: revenue },
      });
    }

    await post(driver.token, `/v1/food/orders/${orderId}/deliver`).send({ deliveryCode }).expect(200);
    const fare = placed.body.data.deliveryFareVnd as number;
    expect(
      await db.jobEarning.findUniqueOrThrow({
        where: { entityType_entityId: { entityType: 'FOOD_ORDER', entityId: orderId } },
      }),
    ).toMatchObject({ feeBps: 1000, feeVnd: Math.round(fare / 10) });
    const events = await db.ledgerJournal.findMany({
      where: { entityId: orderId },
      select: { event: true },
    });
    expect(events.map((row) => row.event).sort()).toEqual([
      'COD_OBLIGATION_POSTED',
      'DRIVER_PLATFORM_FEE_ACCRUED',
      // Store commission on the subtotal (FOOD_MERCHANT_COMMISSION_PERCENT, DRAFT).
      'MERCHANT_COMMISSION_ACCRUED',
    ]);
    await settings.patch('FOOD_DRIVER_COMMISSION_PERCENT', '0', 'pg test reset', driver.userId);
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
