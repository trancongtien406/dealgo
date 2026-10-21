import { describe, expect, it, vi } from 'vitest';
import { MemoryRatingRepository } from './rating.repository.js';
import { RatingService } from './rating.service.js';

const RIDE = '00000000-0000-4000-8000-0000000000a1';
const ORDER = '00000000-0000-4000-8000-0000000000b1';

function setup(
  overrides: {
    rideStatus?: string;
    orderStatus?: string;
    orderDriver?: string | null;
    finishedAt?: Date;
    windowDays?: number;
  } = {},
) {
  const finishedAt = overrides.finishedAt ?? new Date();
  const ratings = new MemoryRatingRepository();
  const rides = {
    ratingSubject: vi.fn(async (id: string) =>
      id === RIDE
        ? {
            customerId: 'cust',
            driverId: 'drv',
            storeId: null,
            status: overrides.rideStatus ?? 'COMPLETED',
            finishedAt,
          }
        : null,
    ),
  };
  const food = {
    ratingSubject: vi.fn(async (id: string) =>
      id === ORDER
        ? {
            customerId: 'cust',
            driverId: overrides.orderDriver === undefined ? 'drv' : overrides.orderDriver,
            storeId: 'store-1',
            status: overrides.orderStatus ?? 'DELIVERED',
            finishedAt,
          }
        : null,
    ),
  };
  const settings = {
    getNumber: vi.fn(async (key: string) => {
      if (key === 'RATING_STORE_MIN_COUNT') {
        return 3;
      }
      expect(key).toBe('RATING_WINDOW_DAYS');
      return overrides.windowDays ?? 7;
    }),
  };
  const service = new RatingService(ratings, rides as never, food as never, settings as never);
  return { service, ratings };
}

describe('RatingService', () => {
  it('rates a completed ride once and reports it', async () => {
    const { service, ratings } = setup();
    const created = await service.submit('cust', {
      subjectType: 'RIDE',
      subjectId: RIDE,
      driverStars: 5,
      tags: ['FRIENDLY', 'FRIENDLY', 'ON_TIME'],
      comment: 'Cảm ơn anh',
    });
    expect(created).toMatchObject({ driverId: 'drv', driverStars: 5, storeStars: null });
    expect(created.tags).toEqual(['FRIENDLY', 'ON_TIME']);
    expect(created).not.toHaveProperty('raterId');
    await expect(
      service.submit('cust', { subjectType: 'RIDE', subjectId: RIDE, driverStars: 1 }),
    ).rejects.toMatchObject({ status: 409 });
    expect(await service.get('cust', 'RIDE', RIDE)).toMatchObject({ canRate: false });
    expect((await ratings.driverSummary('drv')).average).toBe(5);
  });

  it('hides other users rides and refuses unfinished ones', async () => {
    const { service } = setup({ rideStatus: 'IN_TRIP' });
    await expect(
      service.submit('someone-else', { subjectType: 'RIDE', subjectId: RIDE, driverStars: 4 }),
    ).rejects.toMatchObject({ status: 404 });
    await expect(
      service.submit('cust', { subjectType: 'RIDE', subjectId: RIDE, driverStars: 4 }),
    ).rejects.toMatchObject({ status: 422 });
    expect(await service.get('cust', 'RIDE', RIDE)).toEqual({
      rating: null,
      canRate: false,
      rateableUntil: null,
    });
  });

  it('needs driver and store stars on a food order', async () => {
    const { service } = setup();
    await expect(
      service.submit('cust', { subjectType: 'FOOD_ORDER', subjectId: ORDER, driverStars: 4 }),
    ).rejects.toMatchObject({ status: 400 });
    await expect(
      service.submit('cust', { subjectType: 'FOOD_ORDER', subjectId: ORDER, storeStars: 4 }),
    ).rejects.toMatchObject({ status: 400 });
    const created = await service.submit('cust', {
      subjectType: 'FOOD_ORDER',
      subjectId: ORDER,
      driverStars: 4,
      storeStars: 3,
      tags: ['COLD_FOOD'],
    });
    expect(created).toMatchObject({ storeId: 'store-1', storeStars: 3, driverStars: 4 });
  });

  it('closes ratings after the admin-configured window', async () => {
    const day = 86_400_000;
    const late = setup({ finishedAt: new Date(Date.now() - 8 * day) });
    await expect(
      late.service.submit('cust', { subjectType: 'RIDE', subjectId: RIDE, driverStars: 5 }),
    ).rejects.toMatchObject({ status: 422, response: { errorCode: 'RATING_WINDOW_EXPIRED' } });
    expect((await late.service.get('cust', 'RIDE', RIDE)).canRate).toBe(false);

    const longer = setup({ finishedAt: new Date(Date.now() - 8 * day), windowDays: 10 });
    const status = await longer.service.get('cust', 'RIDE', RIDE);
    expect(status.canRate).toBe(true);
    expect(Date.parse(status.rateableUntil!)).toBeGreaterThan(Date.now());
    await expect(
      longer.service.submit('cust', { subjectType: 'RIDE', subjectId: RIDE, driverStars: 5 }),
    ).resolves.toMatchObject({ driverStars: 5 });
  });

  it('rejects store stars on a ride', async () => {
    const { service } = setup();
    await expect(
      service.submit('cust', { subjectType: 'RIDE', subjectId: RIDE, driverStars: 4, storeStars: 5 }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('summarizes driver stars with a distribution', async () => {
    const ratings = new MemoryRatingRepository();
    for (const [i, stars] of [5, 4, 4, 1].entries()) {
      await ratings.create({
        subjectType: 'RIDE',
        subjectId: `r${i}`,
        raterId: 'c',
        driverId: 'drv',
        storeId: null,
        driverStars: stars,
        storeStars: null,
        tags: [],
        comment: null,
      });
    }
    expect(await ratings.driverSummary('drv')).toEqual({
      average: 3.5,
      count: 4,
      distribution: [1, 0, 0, 2, 1],
    });
  });

  it('summarizes store ratings and hides the average below the minimum count', async () => {
    const { service, ratings } = setup();
    const STORE_A = '00000000-0000-4000-8000-00000000aaaa';
    const STORE_B = '00000000-0000-4000-8000-00000000bbbb';
    const STORE_C = '00000000-0000-4000-8000-00000000cccc';
    const rate = (storeId: string, stars: number, n: number) =>
      ratings.create({
        subjectType: 'FOOD_ORDER',
        subjectId: `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`,
        raterId: 'cust',
        driverId: null,
        storeId,
        driverStars: null,
        storeStars: stars,
        tags: [],
        comment: null,
      });
    await rate(STORE_A, 5, 1);
    await rate(STORE_A, 4, 2);
    await rate(STORE_A, 4, 3);
    await rate(STORE_B, 1, 4);

    const out = await service.storeSummaries([STORE_A, STORE_B, STORE_C, STORE_A]);
    expect(out).toEqual([
      { storeId: STORE_A, count: 3, average: 4.3 },
      { storeId: STORE_B, count: 1, average: null },
      { storeId: STORE_C, count: 0, average: null },
    ]);
  });

  it('returns store reviews only once the minimum count is reached', async () => {
    const { service, ratings } = setup();
    const STORE = '00000000-0000-4000-8000-00000000dddd';
    const rate = (stars: number, n: number, comment: string | null) =>
      ratings.create({
        subjectType: 'FOOD_ORDER',
        subjectId: `00000000-0000-4000-8000-${String(100 + n).padStart(12, '0')}`,
        raterId: `cust-${n}`,
        driverId: null,
        storeId: STORE,
        driverStars: null,
        storeStars: stars,
        tags: [],
        comment,
      });
    await rate(5, 1, 'Ngon');
    await rate(4, 2, null);
    const hidden = await service.storeReviews(STORE);
    expect(hidden).toEqual({ summary: { storeId: STORE, count: 2, average: null }, items: [] });

    await rate(3, 3, 'Hơi mặn');
    const shown = await service.storeReviews(STORE);
    expect(shown.summary).toEqual({ storeId: STORE, count: 3, average: 4 });
    expect(shown.items).toHaveLength(3);
    expect(shown.items[0]).not.toHaveProperty('raterId');
    expect(new Set(shown.items.map((i) => i.comment))).toEqual(new Set(['Hơi mặn', 'Ngon', null]));
  });
});
