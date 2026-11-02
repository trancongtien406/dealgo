/**
 * DEC-PROD-033 — item option groups persisted in food_option_groups/food_options, priced inside
 * the placement transaction and snapshotted as JSON on food_order_lines. Skips without DATABASE_URL.
 */
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('food item options (postgres)', () => {
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

  it('stores groups in order, keeps ids on edit and snapshots priced choices on lines', async () => {
    const db = prisma.db()!;
    const repo = new PrismaFoodRepository(db as never);
    const tag = Date.now().toString().slice(-7);
    const owner = await db.user.create({ data: { displayName: 'Option Owner' } });
    const customer = await db.user.create({ data: { displayName: 'Option Customer', phone: `+8493${tag}` } });
    await db.foodStore.create({ data: { ownerId: owner.id, name: `Options ${tag}` } });
    const item = await repo.createItem({ ownerId: owner.id, name: 'Trà sữa', priceVnd: 30_000 });
    await db.foodItem.update({ where: { id: item.id }, data: { moderationStatus: 'APPROVED' } }); // FOOD-001

    const saved = await repo.replaceItemOptions({
      ownerId: owner.id,
      itemId: item.id,
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
        { name: 'Topping', minSelect: 0, maxSelect: 1, options: [{ name: 'Trân châu', priceDeltaVnd: 5_000 }] },
      ],
    });
    expect(saved.optionGroups.map((group) => group.name)).toEqual(['Size', 'Topping']);
    const [size, topping] = saved.optionGroups;
    const large = size.options[1];

    const store = await db.foodStore.findFirstOrThrow({ where: { ownerId: owner.id } });
    const order = await repo.place({
      customerId: customer.id,
      storeId: store.id,
      idempotencyKey: `idem-options-${tag}`,
      items: [{ itemId: item.id, quantity: 2, optionIds: [large.id, topping.options[0].id] }],
      dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
      deliveryFareVnd: 15_000,
    });
    expect(order.subtotalVnd).toBe(86_000);
    expect(order.lines[0].options.map((option) => option.name)).toEqual(['L', 'Trân châu']);

    const edited = await repo.replaceItemOptions({
      ownerId: owner.id,
      itemId: item.id,
      groups: [
        {
          id: size.id,
          name: 'Size',
          minSelect: 1,
          maxSelect: 1,
          options: [{ id: large.id, name: 'L lớn', priceDeltaVnd: 10_000 }],
        },
      ],
    });
    expect(edited.optionGroups[0].id).toBe(size.id);
    expect(edited.optionGroups[0].options[0].id).toBe(large.id);
    expect(await db.foodOptionGroup.count({ where: { itemId: item.id } })).toBe(1);

    const reread = await repo.findOrder(order.id);
    expect(reread?.lines[0].options[0]).toMatchObject({ name: 'L', priceDeltaVnd: 8_000 });
    expect((await repo.findStore(store.id))?.items[0].optionGroups[0].options[0].name).toBe('L lớn');
  });

  it('rejects an unsatisfiable required group with FOOD_OPTION_INVALID inside placement', async () => {
    const db = prisma.db()!;
    const repo = new PrismaFoodRepository(db as never);
    const tag = (Date.now() + 1).toString().slice(-7);
    const owner = await db.user.create({ data: { displayName: 'Option Owner 2' } });
    const customer = await db.user.create({ data: { displayName: 'Option Customer 2', phone: `+8492${tag}` } });
    const store = await db.foodStore.create({ data: { ownerId: owner.id, name: `Options2 ${tag}` } });
    const item = await repo.createItem({ ownerId: owner.id, name: 'Cơm gà', priceVnd: 40_000 });
    await db.foodItem.update({ where: { id: item.id }, data: { moderationStatus: 'APPROVED' } }); // FOOD-001
    const saved = await repo.replaceItemOptions({
      ownerId: owner.id,
      itemId: item.id,
      groups: [{ name: 'Phần', minSelect: 1, maxSelect: 1, options: [{ name: 'Đùi', priceDeltaVnd: 5_000 }] }],
    });
    await expect(
      repo.place({
        customerId: customer.id,
        storeId: store.id,
        idempotencyKey: `idem-options2-${tag}`,
        items: [{ itemId: item.id, quantity: 1 }],
        dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
        deliveryFareVnd: 15_000,
      }),
    ).rejects.toMatchObject({ code: 'FOOD_OPTION_INVALID' });
    expect(await db.foodOrder.count({ where: { customerId: customer.id } })).toBe(0);
    const ok = await repo.place({
      customerId: customer.id,
      storeId: store.id,
      idempotencyKey: `idem-options2-ok-${tag}`,
      items: [{ itemId: item.id, quantity: 1, optionIds: [saved.optionGroups[0].options[0].id] }],
      dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
      deliveryFareVnd: 15_000,
    });
    expect(ok.subtotalVnd).toBe(45_000);
  });
});
