/**
 * Merchant stats query against Postgres: owner scoping, status buckets, top items (groupBy
 * through the order → store relation). Skips when DATABASE_URL is unset.
 */
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('merchant stats (postgres)', () => {
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

  it('counts only the owner\'s finished orders since the window start', async () => {
    const db = prisma.db()!;
    const repo = new PrismaFoodRepository(db as never);
    const tag = Date.now().toString().slice(-7);
    const owner = await db.user.create({ data: { displayName: 'Stats Owner' } });
    const other = await db.user.create({ data: { displayName: 'Other Owner' } });
    const customer = await db.user.create({ data: { displayName: 'Stats Customer', phone: `+8493${tag}` } });
    const store = await db.foodStore.create({ data: { ownerId: owner.id, name: `Stats ${tag}` } });
    const otherStore = await db.foodStore.create({ data: { ownerId: other.id, name: `Other ${tag}` } });
    const item = await db.foodItem.create({ data: { storeId: store.id, name: 'Bánh mì', priceVnd: 20_000 } });
    const since = new Date(Date.now() - 86_400_000);
    let serial = 0;
    const order = (storeId: string, status: string, qty: number, updatedAt = new Date()) =>
      db.foodOrder.create({
        data: {
          customerId: customer.id,
          storeId,
          status: status as never,
          deliveryFareVnd: 15_000,
          subtotalVnd: 20_000 * qty,
          totalVnd: 20_000 * qty + 15_000,
          dropoffLat: 16,
          dropoffLng: 108,
          dropoffLabel: 'x',
          idempotencyKey: `stats-${tag}-${(serial += 1)}`,
          updatedAt,
          lines: { create: [{ itemId: item.id, name: 'Bánh mì', unitPriceVnd: 20_000, quantity: qty }] },
        },
      });
    await order(store.id, 'DELIVERED', 3);
    await order(store.id, 'DELIVERED', 1);
    await order(store.id, 'CANCELLED', 2);
    await order(store.id, 'DELIVERED', 5, new Date(Date.now() - 3 * 86_400_000));
    await order(otherStore.id, 'DELIVERED', 9);

    const rows = await repo.merchantStats(owner.id, since, 5);
    expect(rows.finished.filter((row) => row.status === 'DELIVERED')).toHaveLength(2);
    expect(rows.finished.filter((row) => row.status === 'CANCELLED')).toHaveLength(1);
    expect(rows.finished.reduce((sum, row) => sum + (row.status === 'DELIVERED' ? row.subtotalVnd : 0), 0)).toBe(80_000);
    expect(rows.topItems).toEqual([{ name: 'Bánh mì', quantity: 4 }]);
    expect(rows.openCount).toBe(0);
  });
});
