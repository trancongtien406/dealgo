/**
 * DEC-PROD-036: food delivery / handover codes — one code per (order, kind) under concurrent
 * first reads, and concurrent wrong guesses never exceed the attempt limit. Skips without DATABASE_URL.
 */
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';
import { PrismaFoodOrderCodeStore } from '../../src/modules/food-order/food-order-code.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('food order codes (postgres)', () => {
  let prisma: PrismaService;
  let close: () => Promise<void>;

  beforeAll(async () => {
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
            }),
        }),
        PrismaModule,
      ],
    }).compile();
    const app = moduleRef.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
    close = () => app.close();
  });

  afterAll(async () => {
    await close();
  });

  it('issues one code per kind and bounds concurrent attempts', async () => {
    const db = prisma.db()!;
    const food = new PrismaFoodRepository(db as never);
    const codes = new PrismaFoodOrderCodeStore(db as never);
    const tag = Date.now().toString().slice(-7);
    const owner = await db.user.create({ data: { displayName: 'Code Owner' } });
    const customer = await db.user.create({ data: { displayName: 'Code Customer', phone: `+8492${tag}` } });
    const store = await db.foodStore.create({
      data: { ownerId: owner.id, name: `Codes ${tag}`, lat: 16.06, lng: 108.22, addressLabel: 'Quán' },
    });
    const item = await food.createItem({ ownerId: owner.id, name: 'Bún', priceVnd: 30_000 });
    const order = await food.place({
      customerId: customer.id,
      storeId: store.id,
      idempotencyKey: `idem-codes-${tag}`,
      items: [{ itemId: item.id, quantity: 1 }],
      dropoff: { lat: 16.05, lng: 108.2, label: 'Nhà' },
      deliveryFareVnd: 15_000,
    });

    const firsts = await Promise.all(
      ['1111', '2222', '3333', '4444'].map((fresh) => codes.ensure(order.id, 'DELIVERY', fresh)),
    );
    expect(new Set(firsts.map((row) => row.code)).size).toBe(1);
    const handover = await codes.ensure(order.id, 'HANDOVER', '9999');
    expect(handover.code).toBe('9999');
    expect(await db.foodOrderCode.count({ where: { orderId: order.id } })).toBe(2);

    const reserved = await Promise.all(
      Array.from({ length: 8 }, () => codes.reserveAttempt(order.id, 'DELIVERY', 3)),
    );
    expect(reserved.filter(Boolean)).toHaveLength(3);
    // The handover code keeps its own budget.
    expect(await codes.reserveAttempt(order.id, 'HANDOVER', 3)).toBe(true);
    await codes.markVerified(order.id, 'HANDOVER', new Date());
    const row = await db.foodOrderCode.findUniqueOrThrow({
      where: { orderId_kind: { orderId: order.id, kind: 'HANDOVER' } },
    });
    expect(row.failedAttempts).toBe(0);
    expect(row.verifiedAt).not.toBeNull();
  });
});
