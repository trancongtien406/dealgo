/**
 * closesAtToday on the Prisma browse SQL and store detail, checked against the in-memory twin.
 * Covers the closure-today/overnight-spill parity required by DEC-PROD-029 and the
 * multi-shift tie-break. Skips when DATABASE_URL is unset, like the other pg specs here.
 */
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { MemoryFoodRepository } from '../../src/modules/food-order/food.repository.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';
import {
  closesAtToday,
  formatClock,
  vnClock,
  withinSchedule,
  type StoreSchedule,
} from '../../src/modules/food-order/store-schedule.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

const PIN = { lat: 16.0544, lng: 108.2022, addressLabel: 'Hải Châu' };

describePg('food store closesAtToday (postgres)', () => {
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
    tag = `Closes${Date.now().toString().slice(-7)}`;
  });

  async function store(name: string, mode: 'OPEN' | 'PAUSED' = 'OPEN') {
    const owner = await prisma.db()!.user.create({ data: { displayName: name } });
    return prisma.db()!.foodStore.create({
      data: { ownerId: owner.id, name: `${tag} ${name}`, serviceMode: mode, ...PIN },
    });
  }

  async function browse(storeId: string) {
    const page = await repo.listStores({
      page: 1,
      limit: 10,
      search: tag,
      radiusKm: 10,
      sortBy: 'name',
    });
    return page.items.find((item) => item.id === storeId);
  }

  it('reports the closing time of the shift serving now in both browse and detail', async () => {
    const now = new Date();
    const today = vnClock(now);
    if (today.minute >= 1439) {
      return; // the 00:00–23:59 fixture stops serving in the last minute of the day
    }
    const row = await store('Scheduled');
    const schedule: StoreSchedule = {
      hoursConfigured: true,
      lastOrderMinutes: 0,
      hours: [{ weekday: today.weekday, opensMinute: 0, closesMinute: 1439 }],
      closures: [],
    };

    const saved = await repo.updateStoreSchedule({ ownerId: row.ownerId, schedule });
    expect(saved).toMatchObject({ openNow: true, closesAtToday: '23:59' });
    expect(await browse(row.id)).toMatchObject({ openNow: true, closesAtToday: '23:59' });
    expect((await repo.findStore(row.id))?.closesAtToday).toBe('23:59');
  });

  it('agrees with the in-memory twin for an overnight shift spilling into today', async () => {
    const now = new Date();
    const today = vnClock(now);
    const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
    if (today.minute < 5 || today.minute >= 1370) {
      return; // the fixture needs room below 23:00 and above 00:05
    }
    const closesMinute = today.minute + 10;
    const schedule: StoreSchedule = {
      hoursConfigured: true,
      lastOrderMinutes: 0,
      hours: [{ weekday: yesterday.weekday, opensMinute: 23 * 60, closesMinute }],
      closures: [],
    };
    expect(closesAtToday(schedule, now)).toBe(formatClock(closesMinute));

    const row = await store('Overnight');
    const saved = await repo.updateStoreSchedule({ ownerId: row.ownerId, schedule });
    expect(saved.closesAtToday).toBe(formatClock(closesMinute));
    expect(await browse(row.id)).toMatchObject({
      openNow: true,
      closesAtToday: formatClock(closesMinute),
    });

    const memory = await memoryTwin('Overnight', schedule);
    expect(memory.detail).toBe(formatClock(closesMinute));
    expect(memory.browse).toBe(formatClock(closesMinute));
  });

  it('keeps the overnight shift alive when today itself is a closed day', async () => {
    const now = new Date();
    const today = vnClock(now);
    const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
    if (today.minute < 5 || today.minute >= 1370) {
      return;
    }
    const closesMinute = today.minute + 10;
    const schedule: StoreSchedule = {
      hoursConfigured: true,
      lastOrderMinutes: 0,
      hours: [{ weekday: yesterday.weekday, opensMinute: 23 * 60, closesMinute }],
      closures: [{ date: today.date, note: 'Nghỉ' }],
    };
    expect(withinSchedule(schedule, now)).toBe(true);
    expect(closesAtToday(schedule, now)).toBe(formatClock(closesMinute));

    const row = await store('Closed Today');
    const saved = await repo.updateStoreSchedule({ ownerId: row.ownerId, schedule });
    expect(saved).toMatchObject({
      openNow: true,
      closesAtToday: formatClock(closesMinute),
    });
    expect(await browse(row.id)).toMatchObject({
      openNow: true,
      closesAtToday: formatClock(closesMinute),
    });
    expect((await repo.findStore(row.id))?.closesAtToday).toBe(formatClock(closesMinute));

    const memory = await memoryTwin('Closed Today', schedule);
    expect(memory.detail).toBe(formatClock(closesMinute));
    expect(memory.browse).toBe(formatClock(closesMinute));
  });

  it('reports no closing time for a store without saved hours', async () => {
    const row = await store('Always Open');
    expect(await browse(row.id)).toMatchObject({ openNow: true, closesAtToday: null });
    expect((await repo.findStore(row.id))?.closesAtToday).toBeNull();
  });

  it('reports no closing time for a paused store or one closed all day', async () => {
    const today = vnClock(new Date());
    const paused = await store('Paused', 'PAUSED');
    expect(await browse(paused.id)).toMatchObject({ openNow: false, closesAtToday: null });
    expect((await repo.findStore(paused.id))?.closesAtToday).toBeNull();

    const shut = await store('Shut');
    await repo.updateStoreSchedule({
      ownerId: shut.ownerId,
      schedule: {
        hoursConfigured: true,
        lastOrderMinutes: 0,
        hours: [1, 2, 3, 4, 5, 6, 7]
          .filter((weekday) => weekday !== today.weekday)
          .map((weekday) => ({ weekday, opensMinute: 0, closesMinute: 1440 })),
        closures: [],
      },
    });
    expect(await browse(shut.id)).toMatchObject({ openNow: false, closesAtToday: null });
    expect((await repo.findStore(shut.id))?.closesAtToday).toBeNull();
  });

  it('breaks the multi-shift tie on the earliest closing time, in SQL and in memory', async () => {
    const now = new Date();
    const today = vnClock(now);
    const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
    if (today.minute >= 1370) {
      return; // keeps yesterday's 23:00 shift overnight (it must close before it opens)
    }
    const closesMinute = today.minute + 10;
    const schedule: StoreSchedule = {
      hoursConfigured: true,
      lastOrderMinutes: 0,
      hours: [
        { weekday: yesterday.weekday, opensMinute: 23 * 60, closesMinute },
        { weekday: today.weekday, opensMinute: 0, closesMinute: 1440 },
      ],
      closures: [],
    };
    expect(withinSchedule(schedule, now)).toBe(true);
    expect(closesAtToday(schedule, now)).toBe(formatClock(closesMinute));

    const row = await store('Overlap');
    await repo.updateStoreSchedule({ ownerId: row.ownerId, schedule });
    expect(await browse(row.id)).toMatchObject({
      openNow: true,
      closesAtToday: formatClock(closesMinute),
    });
    expect((await repo.findStore(row.id))?.closesAtToday).toBe(formatClock(closesMinute));

    const memory = await memoryTwin('Overlap', schedule);
    expect(memory.browse).toBe(formatClock(closesMinute));
    expect(memory.detail).toBe(formatClock(closesMinute));
  });

  /** Same schedule through MemoryFoodRepository, so a drift between the twins fails here. */
  async function memoryTwin(name: string, schedule: StoreSchedule) {
    const memory = new MemoryFoodRepository();
    const owner = `memory-${name}-${tag}`;
    const created = await memory.createStore(owner, `${tag} ${name}`, [
      { name: 'Cơm gà', priceVnd: 35_000 },
    ]);
    await memory.updateStoreLocation({ ownerId: owner, ...PIN });
    const detail = await memory.updateStoreSchedule({ ownerId: owner, schedule });
    const page = await memory.listStores({
      page: 1,
      limit: 10,
      search: `${tag} ${name}`,
      radiusKm: 10,
      sortBy: 'name',
    });
    const listed = page.items.find((item) => item.id === created.id);
    return {
      detail: detail.closesAtToday,
      browse: listed?.closesAtToday ?? null,
    };
  }
});
