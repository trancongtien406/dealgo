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

  it('groups journals by UTC day', async () => {
    const service = new SettlementService({
      db: () => ({
        ledgerJournal: {
          findMany: async () => [
            {
              entityType: 'RIDE',
              amountVnd: 30_000,
              postedAt: new Date('2026-10-14T10:00:00.000Z'),
            },
            {
              entityType: 'FOOD_ORDER',
              amountVnd: 70_000,
              postedAt: new Date('2026-10-14T12:00:00.000Z'),
            },
            {
              entityType: 'RIDE',
              amountVnd: 20_000,
              postedAt: new Date('2026-10-13T23:00:00.000Z'),
            },
          ],
        },
      }),
    } as never);

    const page = await service.list(1, 20);
    expect(page.total).toBe(2);
    expect(page.items[0]).toEqual({
      day: '2026-10-14',
      journalCount: 2,
      totalAmountVnd: 100_000,
      entityTypes: ['RIDE', 'FOOD_ORDER'],
    });
    expect(page.items[1]).toEqual({
      day: '2026-10-13',
      journalCount: 1,
      totalAmountVnd: 20_000,
      entityTypes: ['RIDE'],
    });
  });
});
