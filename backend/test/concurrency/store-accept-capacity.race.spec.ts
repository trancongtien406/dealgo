/**
 * DEC-PROD-028 — M022 kitchen cap enforced in the placement transaction under a store row lock:
 * concurrent checkouts never overshoot maxActiveOrders. Skips when DATABASE_URL is unset.
 */
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('store accept capacity (postgres)', () => {
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

  it('admits exactly maxActiveOrders concurrent checkouts and auto-accepts them', async () => {
    const db = prisma.db()!;
    const repo = new PrismaFoodRepository(db as never);
    const tag = Date.now().toString().slice(-7);
    const owner = await db.user.create({ data: { displayName: 'Cap Owner' } });
    const store = await db.foodStore.create({ data: { ownerId: owner.id, name: `Cap ${tag}` } });
    const item = await db.foodItem.create({
      data: { storeId: store.id, name: 'Cơm tấm', priceVnd: 40_000, moderationStatus: 'APPROVED' },
    });
    await repo.updateStoreAcceptSettings({
      ownerId: owner.id,
      acceptMode: 'AUTO',
      maxActiveOrders: 2,
      defaultPrepMinutes: 25,
      lastOrderMinutes: 0,
    });
    const customers = await Promise.all(
      [0, 1, 2, 3, 4, 5].map((index) =>
        db.user.create({ data: { displayName: `Cap Customer ${index}`, phone: `+8495${tag}${index}` } }),
      ),
    );
    const results = await Promise.allSettled(
      customers.map((customer, index) =>
        repo.place({
          customerId: customer.id,
          storeId: store.id,
          idempotencyKey: `idem-cap-${tag}-${index}`,
          items: [{ itemId: item.id, quantity: 1 }],
          dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
          deliveryFareVnd: 15_000,
        }),
      ),
    );
    const admitted = results.filter((result) => result.status === 'fulfilled');
    const refused = results.filter((result) => result.status === 'rejected');
    expect(admitted).toHaveLength(2);
    for (const result of refused) {
      expect((result as PromiseRejectedResult).reason).toMatchObject({ code: 'FOOD_STORE_AT_CAPACITY' });
    }
    for (const result of admitted) {
      expect((result as PromiseFulfilledResult<{ status: string; prepMinutes: number | null }>).value)
        .toMatchObject({ status: 'PREPARING', prepMinutes: 25 });
    }
    expect(
      await db.foodOrder.count({ where: { storeId: store.id, status: { in: ['PLACED', 'PREPARING'] } } }),
    ).toBe(2);
    const outbox = await db.outboxMessage.count({
      where: {
        aggregateType: 'FoodOrder',
        aggregateId: { in: admitted.map((result) => (result as PromiseFulfilledResult<{ id: string }>).value.id) },
      },
    });
    expect(outbox).toBe(2);
  });
});
