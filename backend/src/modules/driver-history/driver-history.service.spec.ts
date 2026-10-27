import { describe, expect, it } from 'vitest';
import { MemoryEarningsRepository } from '../earnings/earnings.repository.js';
import { MemoryRatingRepository } from '../rating/rating.repository.js';
import { DriverHistoryService, vnDate, vnStartOfDay } from './driver-history.service.js';

type Window = { before?: Date; since?: Date; limit: number };
type Row = { id: string; updatedAt: Date; status: string; assignedDriverId: string };

function pick<T extends Row>(rows: T[], driverId: string, window: Window): T[] {
  return rows
    .filter(
      (row) =>
        row.assignedDriverId === driverId &&
        (!window.before || row.updatedAt <= window.before) &&
        (!window.since || row.updatedAt >= window.since),
    )
    .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime() || b.id.localeCompare(a.id))
    .slice(0, window.limit);
}

function ride(id: string, at: string, status = 'COMPLETED', fare = 50_000) {
  return {
    id,
    updatedAt: new Date(at),
    status,
    assignedDriverId: 'drv',
    agreedFareVnd: fare,
    pickup: { lat: 0, lng: 0, label: `Đón ${id}` },
    dropoff: { lat: 0, lng: 0, label: `Trả ${id}` },
  };
}

function order(id: string, at: string, status = 'DELIVERED', fare = 15_000) {
  return {
    id,
    updatedAt: new Date(at),
    status,
    assignedDriverId: 'drv',
    deliveryFareVnd: fare,
    storeName: 'Bún bò Cô Ba',
    dropoff: { lat: 0, lng: 0, label: `Giao ${id}` },
  };
}

function setup(options: { driver?: boolean } = {}) {
  const rides = [
    ride('r1', '2026-10-19T02:00:00.000Z'),
    ride('r2', '2026-10-18T16:30:00.000Z', 'COMPLETED', 40_000), // 23:30 VN on 18/10
    ride('r3', '2026-10-17T17:30:00.000Z', 'CANCELLED'), // 00:30 VN on 18/10
  ];
  const orders = [
    order('o1', '2026-10-19T02:00:00.000Z'), // ties with r1
    order('o2', '2026-10-18T17:30:00.000Z', 'DELIVERED', 20_000), // 00:30 VN on 19/10
    order('o3', '2026-10-10T01:00:00.000Z', 'FAILED'),
  ];
  const ratings = new MemoryRatingRepository();
  const earnings = new MemoryEarningsRepository();
  // r1 completed while the ride fee was 20 %: the snapshot, not today's rate, decides.
  void earnings.recordIfAbsent({
    entityType: 'RIDE',
    entityId: 'r1',
    driverId: 'drv',
    fareVnd: 50_000,
    feeBps: 2000,
    feeVnd: 10_000,
    netVnd: 40_000,
    completedAt: new Date('2026-10-19T02:00:00.000Z'),
  });
  const identity = {
    listGrants: async () => (options.driver === false ? [] : [{ id: 'g', role: 'DRIVER', status: 'ACTIVE' }]),
  };
  const service = new DriverHistoryService(
    identity as never,
    ratings,
    { listFinishedForDriver: async (driverId: string, window: Window) => pick(rides, driverId, window) } as never,
    { listFinishedForDriver: async (driverId: string, window: Window) => pick(orders, driverId, window) } as never,
    { findMany: (subjects: never) => earnings.findMany(subjects) } as never,
  );
  return { service, ratings };
}

describe('DriverHistoryService', () => {
  it('merges rides and orders newest first and pages with a stable cursor', async () => {
    const { service, ratings } = setup();
    await ratings.create({
      subjectType: 'RIDE',
      subjectId: 'r1',
      raterId: 'c',
      driverId: 'drv',
      storeId: null,
      driverStars: 5,
      storeStars: null,
      tags: [],
      comment: null,
    });
    const seen: string[] = [];
    let cursor: string | undefined;
    for (let pageNo = 0; pageNo < 10; pageNo += 1) {
      const page = await service.list('drv', { limit: 2, cursor });
      seen.push(...page.items.map((item) => item.id));
      if (!page.nextCursor) break;
      cursor = page.nextCursor;
    }
    expect(seen).toEqual(['r1', 'o1', 'o2', 'r2', 'r3', 'o3']);
    const first = await service.list('drv', { limit: 1 });
    expect(first.items[0]).toMatchObject({
      kind: 'RIDE',
      outcome: 'COMPLETED',
      fareVnd: 50_000,
      feePercent: 20,
      feeVnd: 10_000,
      earningsVnd: 40_000,
      pickupLabel: 'Đón r1',
      driverStars: 5,
    });
  });

  it('filters by kind and reports zero earnings for cancelled or failed jobs', async () => {
    const { service } = setup();
    const food = await service.list('drv', { kind: 'FOOD_ORDER' });
    expect(food.items.map((item) => item.id)).toEqual(['o1', 'o2', 'o3']);
    expect(food.items[2]).toMatchObject({ outcome: 'FAILED', earningsVnd: 0, storeName: 'Bún bò Cô Ba' });
    const rides = await service.list('drv', { kind: 'RIDE' });
    expect(rides.items.at(-1)).toMatchObject({ outcome: 'CANCELLED', earningsVnd: 0 });
  });

  it('rejects a bad cursor and non-drivers', async () => {
    await expect(setup().service.list('drv', { cursor: 'not-json' })).rejects.toMatchObject({
      status: 400,
    });
    await expect(setup({ driver: false }).service.list('drv')).rejects.toMatchObject({ status: 403 });
    await expect(setup({ driver: false }).service.summary('drv')).rejects.toMatchObject({
      status: 403,
    });
  });

  it('buckets the last 7 days by Asia/Ho_Chi_Minh calendar day', async () => {
    const { service } = setup();
    const summary = await service.summary('drv', new Date('2026-10-19T03:00:00.000Z'));
    expect(summary.days.map((day) => day.date)).toEqual([
      '2026-10-13',
      '2026-10-14',
      '2026-10-15',
      '2026-10-16',
      '2026-10-17',
      '2026-10-18',
      '2026-10-19',
    ]);
    expect(summary.today).toEqual({
      date: '2026-10-19',
      completedJobs: 3,
      grossVnd: 85_000,
      feeVnd: 10_000,
      earningsVnd: 75_000,
    });
    expect(summary.days[5]).toEqual({
      date: '2026-10-18',
      completedJobs: 1,
      grossVnd: 40_000,
      feeVnd: 0,
      earningsVnd: 40_000,
    });
    expect(summary.week).toEqual({
      completedJobs: 4,
      cancelledJobs: 1,
      grossVnd: 125_000,
      feeVnd: 10_000,
      earningsVnd: 115_000,
      rideEarningsVnd: 80_000,
      foodEarningsVnd: 35_000,
    });
    expect(summary.rating.count).toBe(0);
  });

  it('computes VN day boundaries', () => {
    expect(vnDate(new Date('2026-10-18T17:00:00.000Z'))).toBe('2026-10-19');
    expect(vnStartOfDay(new Date('2026-10-19T03:00:00.000Z')).toISOString()).toBe(
      '2026-10-18T17:00:00.000Z',
    );
  });
});

describe('DriverHistoryService.activeJob', () => {
  const identity = { listGrants: async () => [{ id: 'g', role: 'DRIVER', status: 'ACTIVE' }] };
  const make = (rideIds: string[], orderIds: string[]) =>
    new DriverHistoryService(
      identity as never,
      new MemoryRatingRepository(),
      { trackingRideIdsForDriver: async () => rideIds } as never,
      { trackingOrderIdsForDriver: async () => orderIds } as never,
      {} as never,
    );

  it('returns the in-progress ride first, else the food order, else null', async () => {
    expect(await make(['r1'], ['o1']).activeJob('drv')).toEqual({ job: { kind: 'RIDE', id: 'r1' } });
    expect(await make([], ['o1']).activeJob('drv')).toEqual({ job: { kind: 'FOOD_ORDER', id: 'o1' } });
    expect(await make([], []).activeJob('drv')).toEqual({ job: null });
  });
});
