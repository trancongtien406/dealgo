/**
 * Dish search SQL: only available/approved dishes of stores taking orders now, best
 * sellers first, reusing the browse open-state and distance SQL (DEC-PROD-027).
 * Skips when DATABASE_URL is unset, like the other pg specs here.
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

const PIN = { lat: 16.0544, lng: 108.2022, addressLabel: 'Hải Châu' };
const ORIGIN = { lat: 16.05, lng: 108.2 };

describePg('food dish search (postgres)', () => {
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
    tag = `Dish${Date.now().toString().slice(-7)}`;
  });

  async function store(
    name: string,
    options: { mode?: 'OPEN' | 'PAUSED'; pin?: boolean } = {},
  ) {
    const owner = await prisma
      .db()!
      .user.create({ data: { displayName: name } });
    return prisma.db()!.foodStore.create({
      data: {
        ownerId: owner.id,
        name: `${tag} ${name}`,
        serviceMode: options.mode ?? 'OPEN',
        ...(options.pin === false ? {} : PIN),
      },
    });
  }

  async function item(
    storeId: string,
    name: string,
    options: {
      soldCount?: number;
      available?: boolean;
      moderationStatus?: 'PENDING' | 'APPROVED' | 'REJECTED';
      prepMinutes?: number | null;
    } = {},
  ) {
    return prisma.db()!.foodItem.create({
      data: {
        storeId,
        name,
        priceVnd: 45_000,
        soldCount: options.soldCount ?? 0,
        available: options.available ?? true,
        moderationStatus: options.moderationStatus ?? 'APPROVED',
        prepMinutes: options.prepMinutes ?? null,
      },
    });
  }

  function search(q: string, extra: { limit?: number; page?: number } = {}) {
    return repo.searchDishes({
      q,
      page: extra.page ?? 1,
      limit: extra.limit ?? 10,
      ...ORIGIN,
      radiusKm: 10,
    });
  }

  it('lists approved in-stock dishes of open stores, best sellers first', async () => {
    const open = await store('Open');
    const bun = await item(open.id, `Bún bò ${tag}`, { soldCount: 5 });
    const cha = await item(open.id, `Bún chả ${tag}`, {
      soldCount: 9,
      prepMinutes: 7,
    });
    await item(open.id, `Trà đá ${tag}`, { soldCount: 2 });

    const page = await search(tag);
    expect(page.total).toBe(3);
    expect(page.items.map((hit) => hit.item.id)).toEqual([
      cha.id,
      bun.id,
      expect.any(String),
    ]);
    expect(page.items[0]).toMatchObject({
      item: { name: `Bún chả ${tag}`, priceVnd: 45_000, prepMinutes: 7 },
      store: {
        id: open.id,
        name: `${tag} Open`,
        openNow: true,
        closedReason: null,
      },
    });
    // The store default prep fills in for a dish without its own estimate.
    expect(
      page.items.find((hit) => hit.item.id === bun.id)?.item.prepMinutes,
    ).toBe(15);
    expect(page.items[0]!.store.distanceKm).toBeGreaterThan(0);

    const firstPage = await search(tag, { limit: 2 });
    expect(firstPage.total).toBe(3);
    expect(firstPage.items).toHaveLength(2);
    expect((await search(tag, { limit: 2, page: 2 })).items).toHaveLength(1);

    const withoutGeo = await repo.searchDishes({
      q: tag,
      page: 1,
      limit: 10,
      radiusKm: 0,
    });
    expect(withoutGeo.items).toHaveLength(3);
    expect(withoutGeo.items[0]!.store.distanceKm).toBeNull();
  });

  it('hides paused stores, closed days and unapproved or out-of-stock dishes', async () => {
    const open = await store('Live');
    const live = await item(open.id, `Bún chả ${tag}`, { soldCount: 1 });
    await item(open.id, `Bún chả ${tag} hết hàng`, { available: false });
    await item(open.id, `Bún chả ${tag} chờ duyệt`, {
      moderationStatus: 'PENDING',
    });

    const paused = await store('Paused', { mode: 'PAUSED' });
    await item(paused.id, `Bún chả ${tag} bản paused`);

    const unpinned = await store('No Pin', { pin: false });
    await item(unpinned.id, `Bún chả ${tag} bản không pin`);

    const shut = await store('Shut');
    await item(shut.id, `Bún chả ${tag} bản nghỉ`);
    await repo.updateStoreSchedule({
      ownerId: shut.ownerId,
      schedule: {
        hoursConfigured: true,
        lastOrderMinutes: 0,
        hours: [],
        closures: [],
      },
    });

    const page = await search(tag);
    expect(page.total).toBe(1);
    expect(page.items[0]).toMatchObject({
      item: { id: live.id },
      store: { id: open.id, openNow: true, closedReason: null },
    });
  });

  it('agrees with the in-memory twin on filters', async () => {
    const open = await store('Twin');
    await item(open.id, `Bún bò ${tag}`, { soldCount: 3 });
    await item(open.id, `Bún chả ${tag}`, { soldCount: 8 });
    await item(open.id, `Bún chả ${tag} chờ duyệt`, {
      soldCount: 99,
      moderationStatus: 'PENDING',
    });
    const paused = await store('Twin Paused', { mode: 'PAUSED' });
    await item(paused.id, `Bún chả ${tag} bản paused`, { soldCount: 99 });
    const sql = await search(tag);

    const memory = new MemoryFoodRepository();
    const owner = `memory-twin-${tag}`;
    await memory.createStore(owner, `${tag} Twin`, [
      { name: `Bún bò ${tag}`, priceVnd: 45_000 },
      { name: `Bún chả ${tag}`, priceVnd: 45_000 },
      { name: `Bún chả ${tag} chờ duyệt`, priceVnd: 45_000 },
    ]);
    await memory.updateStoreLocation({ ownerId: owner, ...PIN });
    const memoryStore = await memory.findStoreByOwner(owner);
    for (const dish of memoryStore!.items) {
      if (!dish.name.endsWith('chờ duyệt')) {
        await memory.setCatalogModeration(dish.id, 'APPROVED');
      }
    }
    const pausedOwner = `memory-paused-${tag}`;
    await memory.createStore(pausedOwner, `${tag} Twin Paused`, [
      { name: `Bún chả ${tag} bản paused`, priceVnd: 45_000 },
    ]);
    await memory.updateStoreLocation({ ownerId: pausedOwner, ...PIN });
    const pausedStore = await memory.findStoreByOwner(pausedOwner);
    await memory.setCatalogModeration(pausedStore!.items[0]!.id, 'APPROVED');
    await memory.updateStoreServiceMode({
      ownerId: pausedOwner,
      mode: 'PAUSED',
      until: null,
    });

    const memoryPage = await memory.searchDishes({
      q: tag,
      page: 1,
      limit: 10,
      ...ORIGIN,
      radiusKm: 10,
    });
    const pairs = (
      items: { item: { name: string }; store: { name: string } }[],
    ) => items.map((hit) => `${hit.item.name}|${hit.store.name}`).sort();

    expect(memoryPage.total).toBe(2);
    expect(memoryPage.total).toBe(sql.total);
    expect(pairs(memoryPage.items)).toEqual(pairs(sql.items));
  });
});
