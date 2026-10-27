import { SettlementService } from './settlement.service.js';

describe('SettlementService', () => {
  it('returns empty page when Prisma client is unavailable', async () => {
    const service = new SettlementService({
      db: () => null,
    } as never);
    await expect(service.list(1, 20)).resolves.toEqual({
      items: [],
      page: 1,
      limit: 20,
      total: 0,
    });
  });

  it('maps SQL day buckets (Asia/Ho_Chi_Minh) newest first', async () => {
    const service = new SettlementService({
      db: () => ({
        $queryRaw: async () => [
          { day: '2026-10-14', journalCount: 1, totalAmountVnd: 20_000n, entityTypes: ['RIDE'] },
          { day: '2026-10-15', journalCount: 2, totalAmountVnd: 100_000n, entityTypes: ['RIDE', 'FOOD_ORDER'] },
        ],
      }),
    } as never);
    const page = await service.list(1, 20);
    expect(page.total).toBe(2);
    expect(page.items).toEqual([
      { day: '2026-10-15', journalCount: 2, totalAmountVnd: 100_000, entityTypes: ['RIDE', 'FOOD_ORDER'] },
      { day: '2026-10-14', journalCount: 1, totalAmountVnd: 20_000, entityTypes: ['RIDE'] },
    ]);
  });
});
