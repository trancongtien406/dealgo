import { BadRequestException } from '@nestjs/common';
import { describe, expect, it } from 'vitest';
import { filterCatalogModerationItems, MemoryFoodRepository } from '../food-order/food.repository.js';
import { OpsTransactionsService } from '../payment/ops-transactions.service.js';
import { SettlementService } from '../settlement/settlement.service.js';
import { dayKeyInWindow, inDateWindow, opsDateWindow, prismaDateFilter } from './ops-date-window.js';

describe('opsDateWindow (Ops list from/to, Vietnam business days)', () => {
  it('is undefined without bounds', () => {
    expect(opsDateWindow({})).toBeUndefined();
    expect(opsDateWindow({ from: ' ', to: '' })).toBeUndefined();
  });

  it('maps an inclusive day range to [00:00 ICT from, 00:00 ICT day after to)', () => {
    const w = opsDateWindow({ from: '2026-10-20', to: '2026-10-26' })!;
    expect(w.start!.toISOString()).toBe('2026-10-19T17:00:00.000Z');
    expect(w.end!.toISOString()).toBe('2026-10-26T17:00:00.000Z');
  });

  it('keeps a single bound open on the other side', () => {
    expect(opsDateWindow({ from: '2026-10-26' })).toEqual({ start: new Date('2026-10-25T17:00:00.000Z') });
    expect(opsDateWindow({ to: '2026-10-26' })).toEqual({ end: new Date('2026-10-26T17:00:00.000Z') });
  });

  it('rejects from after to and impossible days', () => {
    expect(() => opsDateWindow({ from: '2026-10-27', to: '2026-10-26' })).toThrow(BadRequestException);
    expect(() => opsDateWindow({ from: '2026-02-30' })).toThrow(BadRequestException);
  });

  it('inDateWindow / prismaDateFilter / dayKeyInWindow agree on the edges', () => {
    const w = opsDateWindow({ from: '2026-10-26', to: '2026-10-26' });
    expect(inDateWindow(new Date('2026-10-25T16:59:59.999Z'), w)).toBe(false); // 23:59 ICT 25/10
    expect(inDateWindow(new Date('2026-10-25T17:00:00.000Z'), w)).toBe(true); // 00:00 ICT 26/10
    expect(inDateWindow(new Date('2026-10-26T16:59:59.999Z'), w)).toBe(true);
    expect(inDateWindow(new Date('2026-10-26T17:00:00.000Z'), w)).toBe(false);
    expect(prismaDateFilter(w)).toEqual({ gte: w!.start, lt: w!.end });
    expect(prismaDateFilter(undefined)).toBeUndefined();
    expect(dayKeyInWindow('2026-10-25', { from: '2026-10-26' })).toBe(false);
    expect(dayKeyInWindow('2026-10-26', { from: '2026-10-26', to: '2026-10-26' })).toBe(true);
    expect(dayKeyInWindow('2026-10-27', { to: '2026-10-26' })).toBe(false);
  });
});

describe('Ops lists honour from/to', () => {
  it('transactions: payment intents are queried by createdAt window', async () => {
    const calls: unknown[] = [];
    const service = new OpsTransactionsService({
      db: () => ({
        paymentIntent: {
          findMany: async (args: unknown) => {
            calls.push(args);
            return [];
          },
        },
        ride: { findMany: async () => [] },
        foodOrder: { findMany: async () => [] },
      }),
    } as never);
    await service.list(1, 20, { window: opsDateWindow({ from: '2026-10-20', to: '2026-10-26' }) });
    await service.list(1, 20, {});
    expect(calls[0]).toMatchObject({
      where: {
        createdAt: { gte: new Date('2026-10-19T17:00:00.000Z'), lt: new Date('2026-10-26T17:00:00.000Z') },
      },
    });
    expect(calls[1]).not.toHaveProperty('where');
  });

  it('settlements: only business days inside the range are paged', async () => {
    const service = new SettlementService({
      db: () => ({
        $queryRaw: async () => [
          { day: '2026-10-19', journalCount: 1, totalAmountVnd: 1n, entityTypes: ['RIDE'] },
          { day: '2026-10-20', journalCount: 2, totalAmountVnd: 2n, entityTypes: ['RIDE'] },
          { day: '2026-10-26', journalCount: 3, totalAmountVnd: 3n, entityTypes: ['FOOD_ORDER'] },
          { day: '2026-10-27', journalCount: 4, totalAmountVnd: 4n, entityTypes: ['RIDE'] },
        ],
      }),
    } as never);
    const page = await service.list(1, 20, { from: '2026-10-20', to: '2026-10-26' });
    expect(page.total).toBe(2);
    expect(page.items.map((b) => b.day)).toEqual(['2026-10-26', '2026-10-20']);
  });

  it('food orders (deliveries): memory repository filters by createdAt', async () => {
    const repo = new MemoryFoodRepository();
    const orders = (repo as unknown as { orders: Array<{ id: string; createdAt: Date; status: string }> }).orders;
    const base = { customerId: 'c', storeId: 's', status: 'PLACED', lines: [], dropoff: { label: 'x', lat: 0, lng: 0 } };
    orders.push(
      { ...base, id: 'old', createdAt: new Date('2026-10-25T16:00:00.000Z') } as never,
      { ...base, id: 'in', createdAt: new Date('2026-10-26T01:00:00.000Z') } as never,
    );
    const page = await repo.listOrdersPage(1, 10, { window: opsDateWindow({ from: '2026-10-26', to: '2026-10-26' }) });
    expect(page.items.map((o) => o.id)).toEqual(['in']);
    expect((await repo.listOrdersPage(1, 10, {})).total).toBe(2);
  });

  it('catalog review: items are filtered by submission time', () => {
    const item = (id: string, submittedAt: string) => ({
      id,
      code: id,
      name: id,
      category: 'Phở',
      store: 'Quán',
      price: 1,
      submittedAt,
      status: 'PENDING' as const,
      nameReady: true,
      imageReady: true,
    });
    const page = filterCatalogModerationItems(
      [item('a', '2026-10-25T16:59:00.000Z'), item('b', '2026-10-25T17:00:00.000Z')],
      { window: opsDateWindow({ from: '2026-10-26' }) },
    );
    expect(page.items.map((i) => i.id)).toEqual(['b']);
  });

  it('catalog review: memory items carry a real ISO submission time', async () => {
    const repo = new MemoryFoodRepository();
    await repo.createFixtureStore('owner-1', [{ name: 'Phở bò', priceVnd: 50_000 }]);
    const page = await repo.listCatalogModeration({});
    expect(Number.isNaN(Date.parse(page.items[0].submittedAt))).toBe(false);
  });
});
