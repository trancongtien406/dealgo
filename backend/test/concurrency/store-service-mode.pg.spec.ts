/**
 * DEC-PROD-026 — M024 busy/pause persisted on food_stores and enforced inside the placement
 * transaction. Skips when DATABASE_URL is unset.
 */
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaModule } from '../../src/platform/database/prisma.module.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { vnClock } from '../../src/modules/food-order/store-schedule.js';
import { PrismaFoodRepository } from '../../src/modules/food-order/food-prisma.repository.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('store service mode (postgres)', () => {
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

  it('persists pause with auto-resume and blocks placement only while paused', async () => {
    const db = prisma.db()!;
    const repo = new PrismaFoodRepository(db as never);
    const tag = Date.now().toString().slice(-7);
    const owner = await db.user.create({ data: { displayName: 'Pause Owner' } });
    const customer = await db.user.create({ data: { displayName: 'Pause Customer', phone: `+8494${tag}` } });
    const store = await db.foodStore.create({ data: { ownerId: owner.id, name: `Pause ${tag}` } });
    const item = await db.foodItem.create({
      data: { storeId: store.id, name: 'Bánh mì', priceVnd: 20_000, moderationStatus: 'APPROVED' },
    });
    const place = (key: string) =>
      repo.place({
        customerId: customer.id,
        storeId: store.id,
        idempotencyKey: `idem-pause-${tag}-${key}`,
        items: [{ itemId: item.id, quantity: 1 }],
        dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
        deliveryFareVnd: 15_000,
      });

    const paused = await repo.updateStoreServiceMode({
      ownerId: owner.id,
      mode: 'PAUSED',
      until: new Date(Date.now() + 30 * 60_000),
    });
    expect(paused.serviceMode).toBe('PAUSED');
    expect(paused.serviceModeUntil).not.toBeNull();
    await expect(place('a')).rejects.toMatchObject({ code: 'FOOD_STORE_PAUSED' });

    await db.foodStore.update({
      where: { id: store.id },
      data: { serviceModeUntil: new Date(Date.now() - 1_000) },
    });
    expect((await repo.findStore(store.id))?.serviceMode).toBe('OPEN');
    const order = await place('b');
    expect(order.status).toBe('PLACED');
  });

  it('orders closed/paused stores last in SQL and blocks placement while closed (DEC-PROD-027)', async () => {
    const db = prisma.db()!;
    const repo = new PrismaFoodRepository(db as never);
    const tag = `Hours${Date.now().toString().slice(-7)}`;
    const today = vnClock(new Date());
    const owner = (name: string) => db.user.create({ data: { displayName: name } });
    const customer = await db.user.create({ data: { displayName: 'Hours Customer', phone: `+8495${tag.slice(-7)}` } });
    const [o1, o2, o3] = await Promise.all([owner('A'), owner('B'), owner('C')]);
    // Name order would be A, B, C; A is closed today, B is paused, C is open.
    const a = await db.foodStore.create({ data: { ownerId: o1.id, name: `${tag} A` } });
    const b = await db.foodStore.create({
      data: { ownerId: o2.id, name: `${tag} B`, serviceMode: 'PAUSED' },
    });
    const c = await db.foodStore.create({ data: { ownerId: o3.id, name: `${tag} C` } });
    const item = await db.foodItem.create({ data: { storeId: a.id, name: 'Phở', priceVnd: 40_000 } });

    const saved = await repo.updateStoreSchedule({
      ownerId: o1.id,
      schedule: {
        hoursConfigured: true,
        lastOrderMinutes: 0,
        hours: [1, 2, 3, 4, 5, 6, 7]
          .filter((weekday) => weekday !== today.weekday)
          .map((weekday) => ({ weekday, opensMinute: 0, closesMinute: 1440 })),
        closures: [{ date: '2027-01-01', note: 'Tết' }],
      },
    });
    expect(saved).toMatchObject({ openNow: false, closedReason: 'CLOSED' });
    expect(saved.schedule.closures).toEqual([{ date: '2027-01-01', note: 'Tết' }]);

    const page = await repo.listStores({
      page: 1,
      limit: 10,
      search: tag,
      radiusKm: 10,
      sortBy: 'name',
    });
    expect(page.items.map((store) => store.id)).toEqual([c.id, a.id, b.id]);
    expect(page.items.map((store) => store.closedReason)).toEqual([null, 'CLOSED', 'PAUSED']);

    await expect(
      repo.place({
        customerId: customer.id,
        storeId: a.id,
        idempotencyKey: `idem-hours-${tag}`,
        items: [{ itemId: item.id, quantity: 1 }],
        dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
        deliveryFareVnd: 15_000,
      }),
    ).rejects.toMatchObject({ code: 'FOOD_STORE_CLOSED' });

    const ops = await repo.findStoreForOps(b.id);
    expect(ops).toMatchObject({ serviceMode: 'PAUSED', openNow: false, closedReason: 'PAUSED' });
  });

  it('SQL list agrees with TS for an overnight shift spilling into today (DEC-PROD-029)', async () => {
    const db = prisma.db()!;
    const repo = new PrismaFoodRepository(db as never);
    const now = new Date();
    const today = vnClock(now);
    const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
    if (today.minute > 1340) {
      return; // too close to midnight to build a spill-over window deterministically
    }
    const tag = `Night${Date.now().toString().slice(-7)}`;
    const owner = await db.user.create({ data: { displayName: 'Night Owner' } });
    const store = await db.foodStore.create({ data: { ownerId: owner.id, name: `${tag} Quán Đêm` } });
    // Yesterday 23:00 → today (now + 30 min); no row for today, so only the spill-over opens it.
    const overnight = {
      hoursConfigured: true,
      lastOrderMinutes: 0,
      hours: [{ weekday: yesterday.weekday, opensMinute: 1380, closesMinute: today.minute + 30 }],
      closures: [] as { date: string; note: string | null }[],
    };
    const opened = await repo.updateStoreSchedule({ ownerId: owner.id, schedule: overnight });
    expect(opened).toMatchObject({ openNow: true, closedReason: null });
    const listed = async () =>
      (await repo.listStores({ page: 1, limit: 5, search: tag, radiusKm: 10, sortBy: 'name' })).items[0];
    expect(await listed()).toMatchObject({ id: store.id, openNow: true });

    // The cut-off ends the spill-over early.
    const cut = await repo.updateStoreSchedule({
      ownerId: owner.id,
      schedule: { ...overnight, lastOrderMinutes: 45 },
    });
    expect(cut.openNow).toBe(false);
    expect(await listed()).toMatchObject({ openNow: false, closedReason: 'CLOSED' });

    // A day off on the shift's start date cancels the whole shift, including the morning part.
    const off = await repo.updateStoreSchedule({
      ownerId: owner.id,
      schedule: { ...overnight, closures: [{ date: yesterday.date, note: null }] },
    });
    expect(off.openNow).toBe(false);
    expect(await listed()).toMatchObject({ openNow: false });
  });
});
