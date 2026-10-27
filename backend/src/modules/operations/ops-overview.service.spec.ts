import { InternalServerErrorException } from '@nestjs/common';
import { OpsOverviewService } from './ops-overview.service.js';

const exceptionsStub = {
  countOpen: async () => 0,
  list: async () => ({ items: [], page: 1, limit: 8, total: 0 }),
};

describe('OpsOverviewService', () => {
  it('returns empty KPIs and panels when Prisma client is unavailable', async () => {
    const service = new OpsOverviewService(
      { db: () => null } as never,
      exceptionsStub as never,
    );

    const overview = await service.overview(new Date('2026-10-15T12:00:00.000Z'));
    expect(overview.ridesTotal).toBe(0);
    expect(overview.foodInFlight).toBe(0);
    expect(overview.revenueVnd).toBe(0);
    expect(overview.commissionVnd).toBe(0);
    expect(overview.todayTimezone).toBe('Asia/Ho_Chi_Minh');
    expect(overview.hourlyTrend.buckets).toEqual([]);
    expect(overview.recentActivity).toEqual([]);
    expect(overview.ridesByArea).toEqual([]);
    expect(overview.foodByCategory).toEqual([]);
  });

  it('logs and rethrows InternalServerError when aggregate query fails', async () => {
    const service = new OpsOverviewService(
      {
        db: () => ({
          $queryRaw: async () => {
            throw new Error('statement timeout');
          },
        }),
      } as never,
      exceptionsStub as never,
    );

    await expect(service.overview()).rejects.toBeInstanceOf(
      InternalServerErrorException,
    );
  });

  it('builds overview from exact counts including foodInFlight', async () => {
    const service = new OpsOverviewService(
      {
        db: () => ({
          $queryRaw: async (strings: TemplateStringsArray) => {
            const sql = strings.join(' ');
            if (sql.includes('job_earnings') && sql.includes('FROM rides')) {
              return [{ day: '2026-10-15', completed: 9n, cancelled: 8n, grossVnd: 450_000n, commissionVnd: 45_000n }];
            }
            if (sql.includes('job_earnings') && sql.includes('FROM food_orders')) {
              return [{ day: '2026-10-15', completed: 6n, cancelled: 1n, grossVnd: 300_000n, commissionVnd: 60_000n }];
            }
            if (
              sql.includes('FROM rides') &&
              sql.includes('FROM food_orders') &&
              !sql.includes('WHERE')
            ) {
              return [{ rides: 16n, food: 11n }];
            }
            if (sql.includes('NEGOTIATING') && sql.includes('ASSIGNED')) {
              return [{ negotiating: 2n, assigned: 4n }];
            }
            if (sql.includes('"inFlight"') || sql.includes('inFlight')) {
              return [{ placed: 1n, preparing: 3n, inFlight: 8n }];
            }
            if (sql.includes('COMPLETED') && sql.includes('rides')) {
              return [{ cnt: 9n }];
            }
            if (sql.includes('CANCELLED') && sql.includes('rides')) {
              return [{ cnt: 8n }];
            }
            if (sql.includes('DELIVERED') && sql.includes('food_orders')) {
              return [{ delivered: 6n }];
            }
            if (sql.includes('CUSTOMER')) {
              return [
                {
                  customers: 100n,
                  drivers: 20n,
                  online: 5n,
                  stores: 11n,
                },
              ];
            }
            throw new Error(`unexpected sql: ${sql}`);
          },
          $queryRawUnsafe: async () => {
            throw new Error('enrichment unavailable');
          },
        }),
      } as never,
      { ...exceptionsStub, countOpen: async () => 42 } as never,
    );

    const overview = await service.overview(new Date('2026-10-15T12:00:00.000Z'));
    expect(overview).toEqual(
      expect.objectContaining({
        ridesTotal: 16,
        ridesNegotiating: 2,
        ridesAssigned: 4,
        ridesCompletedToday: 9,
        ridesCancelledToday: 8,
        foodOrdersTotal: 11,
        foodPlaced: 1,
        foodPreparing: 3,
        foodInFlight: 8,
        foodDeliveredToday: 6,
        customersTotal: 100,
        driversTotal: 20,
        driversOnline: 5,
        storesTotal: 11,
        exceptionsOpen: 42,
        revenueVnd: 750_000,
        commissionVnd: 105_000,
        hourlyTrend: { buckets: [] },
        recentActivity: [],
        ridesByArea: [],
        foodByCategory: [],
      }),
    );
  });

  it('returns monitor snapshot with derived queue/alerts when enrichment fails', async () => {
    const service = new OpsOverviewService(
      {
        db: () => ({
          $transaction: async (fn: (tx: unknown) => Promise<unknown>) => {
            const tx = {
              $executeRawUnsafe: async () => undefined,
              $queryRaw: async (strings: TemplateStringsArray) => {
                const sql = strings.join(' ');
                if (sql.includes('FROM rides') && sql.includes('GROUP BY')) {
                  return [
                    { status: 'NEGOTIATING', cnt: 3n },
                    { status: 'ASSIGNED', cnt: 2n },
                  ];
                }
                if (sql.includes('FROM food_orders') && sql.includes('GROUP BY')) {
                  return [
                    { status: 'READY', cnt: 4n },
                    { status: 'ASSIGNED', cnt: 1n },
                  ];
                }
                if (sql.includes('driver_presence')) {
                  return [{ cnt: 0n }];
                }
                throw new Error(`unexpected sql: ${sql}`);
              },
            };
            return fn(tx);
          },
          $queryRaw: async () => {
            throw new Error('enrichment unavailable');
          },
          $queryRawUnsafe: async () => {
            throw new Error('enrichment unavailable');
          },
        }),
      } as never,
      { ...exceptionsStub, countOpen: async () => 2 } as never,
    );

    const snap = await service.monitorSnapshot(
      new Date('2026-10-15T12:00:00.000Z'),
    );
    expect(snap.ridesOpen).toBe(5);
    expect(snap.ridesNegotiating).toBe(3);
    expect(snap.foodReady).toBe(4);
    expect(snap.foodInFlight).toBe(5);
    expect(snap.driversOnline).toBe(0);
    expect(snap.exceptionsOpen).toBe(2);
    expect(snap.mapMarkers).toEqual([]);
    expect(snap.queue.map((q) => q.key)).toEqual([
      'negotiating',
      'food_ready',
      'food_in_flight',
      'exceptions',
    ]);
    expect(snap.systemAlerts.some((a) => a.code === 'exceptions_open')).toBe(
      true,
    );
    expect(snap.systemAlerts.some((a) => a.code === 'drivers_online_zero')).toBe(
      true,
    );
  });
});
