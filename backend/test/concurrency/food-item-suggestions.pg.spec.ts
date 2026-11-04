/**
 * Item-page suggestions: same store, other menu category, in-stock and approved,
 * best sellers first, capped at the requested limit. Skips when DATABASE_URL is
 * unset, like the other pg specs here.
 */
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { MemoryFoodRepository } from '../../src/modules/food-order/food.repository.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('food item suggestions (postgres)', () => {
  let prisma: PrismaService;
  let close: () => Promise<void>;
  let repo: PrismaFoodRepository;
  let tag: string;

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

  beforeEach(() => {
    repo = new PrismaFoodRepository(prisma.db()! as never);
    tag = `Suggest${Date.now().toString().slice(-7)}`;
  });

  async function store(
    name: string,
    options: { mode?: 'OPEN' | 'PAUSED' } = {},
  ) {
    const owner = await prisma
      .db()!
      .user.create({ data: { displayName: `${tag} ${name} owner` } });
    return prisma.db()!.foodStore.create({
      data: {
        ownerId: owner.id,
        name: `${tag} ${name}`,
        serviceMode: options.mode ?? 'OPEN',
        lat: 16.0544,
        lng: 108.2022,
      },
    });
  }

  function category(storeId: string, name: string) {
    return prisma.db()!.foodMenuCategory.create({
      data: { storeId, name: `${tag} ${name}` },
    });
  }

  function item(
    storeId: string,
    name: string,
    menuCategoryId: string | null,
    options: {
      soldCount?: number;
      available?: boolean;
      moderationStatus?: 'PENDING' | 'APPROVED' | 'REJECTED';
      createdAt?: Date;
    } = {},
  ) {
    return prisma.db()!.foodItem.create({
      data: {
        storeId,
        menuCategoryId,
        name: `${tag} ${name}`,
        priceVnd: 30_000,
        soldCount: options.soldCount ?? 0,
        available: options.available ?? true,
        moderationStatus: options.moderationStatus ?? 'APPROVED',
        ...(options.createdAt ? { createdAt: options.createdAt } : {}),
      },
    });
  }

  function optionGroup(itemId: string, minSelect: number) {
    return prisma.db()!.foodOptionGroup.create({
      data: {
        itemId,
        name: `${tag} Size`,
        minSelect,
        maxSelect: 2,
        options: {
          create: [
            { name: 'M', priceDeltaVnd: 0, position: 0 },
            { name: 'L', priceDeltaVnd: 5_000, position: 1 },
          ],
        },
      },
    });
  }

  function suggest(storeId: string, exclude: string[]) {
    return repo.listItemSuggestions({
      storeId,
      exclude,
      limit: 6,
      moderationRequired: true,
    });
  }

  it('skips dishes that require a choice before they can be added plain', async () => {
    const open = await store('Plain');
    const mains = await category(open.id, 'Mains');
    const drinks = await category(open.id, 'Drinks');
    const viewed = await item(open.id, 'Viewed main', mains.id);
    // Topping the list if the rule is missing: a plain tile cannot price a required group.
    const bestSeller = await item(open.id, 'Best seller with sizes', drinks.id, {
      soldCount: 99,
    });
    await optionGroup(bestSeller.id, 1);
    const optional = await item(open.id, 'Optional topping drink', drinks.id, {
      soldCount: 5,
    });
    await optionGroup(optional.id, 0);
    const plain = await item(open.id, 'Plain drink', drinks.id, {
      soldCount: 1,
    });

    const suggestions = await suggest(open.id, [viewed.id]);

    expect(suggestions.map((entry) => entry.name)).toEqual([
      `${tag} Optional topping drink`,
      `${tag} Plain drink`,
    ]);
    expect(suggestions.map((entry) => entry.id)).not.toContain(bestSeller.id);
    expect(suggestions.map((entry) => entry.id)).toContain(optional.id);
    expect(suggestions.map((entry) => entry.id)).toContain(plain.id);
  });

  it('returns other-category in-stock dishes, best sellers first, capped at six', async () => {
    const open = await store('Open');
    const mains = await category(open.id, 'Mains');
    const drinks = await category(open.id, 'Drinks');
    const viewed = await item(open.id, 'Viewed main', mains.id);
    await item(open.id, 'Same-category best seller', mains.id, {
      soldCount: 99,
    });
    await item(open.id, 'Out of stock drink', drinks.id, {
      soldCount: 90,
      available: false,
    });
    await item(open.id, 'Pending drink', drinks.id, {
      soldCount: 80,
      moderationStatus: 'PENDING',
    });
    await item(open.id, 'Uncategorized drink-like dish', null, {
      soldCount: 70,
    });
    const now = Date.now();
    const ordered = [
      { name: 'Drink one', soldCount: 5 },
      { name: 'Drink two', soldCount: 8 },
      { name: 'Drink three', soldCount: 8 },
      { name: 'Drink four', soldCount: 1 },
      { name: 'Drink five', soldCount: 1 },
      { name: 'Drink six', soldCount: 1 },
      { name: 'Drink seven', soldCount: 1 },
    ];
    for (const [index, dish] of ordered.entries()) {
      await item(open.id, dish.name, drinks.id, {
        soldCount: dish.soldCount,
        createdAt: new Date(now - index * 1_000),
      });
    }

    const suggestions = await suggest(open.id, [viewed.id]);

    expect(suggestions).toHaveLength(6);
    expect(suggestions.map((entry) => entry.name)).toEqual([
      `${tag} Drink two`,
      `${tag} Drink three`,
      `${tag} Drink one`,
      `${tag} Drink four`,
      `${tag} Drink five`,
      `${tag} Drink six`,
    ]);
    for (const entry of suggestions) {
      expect(entry).toMatchObject({
        available: true,
        menuCategoryId: drinks.id,
        priceVnd: 30_000,
      });
      expect(entry.id).not.toBe(viewed.id);
    }
  });

  it('returns nothing for unknown, paused stores or when every candidate is filtered out', async () => {
    const paused = await store('Paused', { mode: 'PAUSED' });
    const mains = await category(paused.id, 'Mains');
    const drinks = await category(paused.id, 'Drinks');
    const viewed = await item(paused.id, 'Viewed main', mains.id);
    await item(paused.id, 'Drink one', drinks.id);
    await item(paused.id, 'Drink two', drinks.id);

    expect(await suggest(paused.id, [viewed.id])).toEqual([]);
    expect(
      await suggest('00000000-0000-4000-8000-000000000000', []),
    ).toEqual([]);

    const open = await store('Filtered');
    const openMains = await category(open.id, 'Mains');
    const openDrinks = await category(open.id, 'Drinks');
    const openViewed = await item(open.id, 'Viewed main', openMains.id);
    await item(open.id, 'The only drink', openDrinks.id);

    const only = await suggest(open.id, [openViewed.id]);
    expect(only.map((entry) => entry.name)).toEqual([`${tag} The only drink`]);
  });

  it('agrees with the in-memory twin on filters and order', async () => {
    const open = await store('Twin');
    const mains = await category(open.id, 'Mains');
    const drinks = await category(open.id, 'Drinks');
    const viewed = await item(open.id, 'Main one', mains.id);
    await item(open.id, 'Main two', mains.id);
    const now = Date.now();
    await item(open.id, 'Drink one', drinks.id, {
      createdAt: new Date(now - 2_000),
    });
    await item(open.id, 'Drink two', drinks.id, {
      createdAt: new Date(now - 1_000),
    });
    await item(open.id, 'Drink three', drinks.id, { createdAt: new Date(now) });

    const memory = new MemoryFoodRepository();
    const owner = `memory-suggest-${tag}`;
    await memory.createStore(owner, `${tag} Twin`, [
      { name: 'Main one', priceVnd: 30_000 },
      { name: 'Main two', priceVnd: 30_000 },
    ]);
    const memoryMains = await memory.createMenuCategory({
      ownerId: owner,
      name: 'Mains',
    });
    const memoryDrinks = await memory.createMenuCategory({
      ownerId: owner,
      name: 'Drinks',
    });
    const memoryStore = await memory.findStoreByOwner(owner);
    const [memoryViewed, memoryMainTwo] = memoryStore!.items;
    for (const main of [memoryViewed!, memoryMainTwo!]) {
      await memory.setCatalogModeration(main.id, 'APPROVED');
      await memory.updateItem({
        ownerId: owner,
        itemId: main.id,
        menuCategoryId: memoryMains.id,
      });
    }
    for (const name of ['Drink one', 'Drink two', 'Drink three']) {
      await memory.createItem({
        ownerId: owner,
        name,
        priceVnd: 30_000,
        moderationStatus: 'APPROVED',
        menuCategoryId: memoryDrinks.id,
      });
    }

    const sql = await suggest(open.id, [viewed.id]);
    const twin = await memory.listItemSuggestions({
      storeId: memoryStore!.id,
      exclude: [memoryViewed!.id],
      limit: 6,
      moderationRequired: true,
    });

    // Memory dish insertion order is newest-first, matching the SQL createdAt DESC.
    expect(sql.map((entry) => entry.name)).toEqual(
      ['Drink three', 'Drink two', 'Drink one'].map((name) => `${tag} ${name}`),
    );
    expect(twin.map((entry) => entry.name)).toEqual([
      'Drink three',
      'Drink two',
      'Drink one',
    ]);
    expect(
      twin.map((entry) => entry.menuCategoryId === memoryDrinks.id),
    ).toEqual(sql.map((entry) => entry.menuCategoryId === drinks.id));
  });
});
