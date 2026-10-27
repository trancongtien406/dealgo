import { BadRequestException } from '@nestjs/common';
import { foldPeriodRows, OpsReportsService } from './ops-reports.service.js';

describe('ops reports', () => {
  it('folds ride and food rows into ordered Vietnam-day buckets and totals', () => {
    const { daily, totals } = foldPeriodRows(
      ['2026-10-01', '2026-10-02'],
      [
        { day: '2026-10-02', completed: 3n, cancelled: 1n, grossVnd: 150_000n, commissionVnd: 15_000n },
        { day: '2026-09-30', completed: 9n, cancelled: 9n, grossVnd: 9n, commissionVnd: 9n },
      ],
      [{ day: '2026-10-01', completed: 2n, cancelled: 1n, grossVnd: 200_000n, commissionVnd: 40_000n }],
    );
    expect(daily).toEqual([
      { day: '2026-10-01', ridesCompleted: 0, ridesCancelled: 0, foodDelivered: 2, foodCancelled: 1, revenueVnd: 200_000, commissionVnd: 40_000 },
      { day: '2026-10-02', ridesCompleted: 3, ridesCancelled: 1, foodDelivered: 0, foodCancelled: 0, revenueVnd: 150_000, commissionVnd: 15_000 },
    ]);
    expect(totals).toEqual({
      ridesCompleted: 3,
      ridesCancelled: 1,
      foodDelivered: 2,
      foodCancelled: 1,
      revenueVnd: 350_000,
      commissionVnd: 55_000,
      rideRevenueVnd: 150_000,
      foodRevenueVnd: 200_000,
    });
  });

  it('queries the requested VN range and passes the bounds to SQL', async () => {
    const bounds: unknown[][] = [];
    const service = new OpsReportsService({
      db: () => ({
        $queryRaw: async (strings: TemplateStringsArray, ...values: unknown[]) => {
          bounds.push(values);
          const sql = strings.join(' ');
          return sql.includes('FROM rides')
            ? [{ day: '2026-10-05', completed: 1n, cancelled: 0n, grossVnd: 50_000n, commissionVnd: 5_000n }]
            : [];
        },
      }),
    } as never);
    const report = await service.report({ from: '2026-10-05', to: '2026-10-06' }, new Date('2026-10-10T00:00:00Z'));
    expect(report.totals.revenueVnd).toBe(50_000);
    expect(report.daily).toHaveLength(2);
    expect(bounds[0]).toEqual([new Date('2026-10-04T17:00:00.000Z'), new Date('2026-10-06T17:00:00.000Z')]);
  });

  it('rejects invalid ranges and returns zeros without a database', async () => {
    const service = new OpsReportsService({ db: () => null } as never);
    await expect(service.report({ from: '2026-10-05', to: '2026-10-01' })).rejects.toBeInstanceOf(BadRequestException);
    const empty = await service.report({}, new Date('2026-10-13T17:30:00.000Z'));
    expect(empty.from).toBe('2026-10-14');
    expect(empty.totals.revenueVnd).toBe(0);
  });
});
