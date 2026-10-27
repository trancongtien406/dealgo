import { describe, expect, it } from 'vitest';
import { assertFailWaitOver, MemoryFoodRepository } from './food.repository.js';
import { merchantCommissionVnd } from './food.service.js';

const dropoff = { lat: 10.7769, lng: 106.7009, label: 'Bến Thành' };

async function pickedUp(repo: MemoryFoodRepository, at: Date) {
  await repo.createFixtureStore('owner-1', [{ name: 'Phở bò', priceVnd: 50_000 }]);
  const store = (await repo.findStoreByOwner('owner-1'))!;
  const order = await repo.place({
    customerId: 'cust-1',
    storeId: store.id,
    idempotencyKey: 'fail',
    deliveryFareVnd: 15_000,
    items: [{ itemId: store.items[0].id, quantity: 1 }],
    dropoff,
  });
  await repo.accept(order.id, 'owner-1');
  await repo.markReady(order.id, 'owner-1');
  await repo.claim(order.id, 'driver-1', 2);
  return repo.pickup(order.id, 'driver-1', { merchantCashVnd: 50_000, at });
}

describe('food delivery failure and merchant statements', () => {
  it('commission is a rounded share of the subtotal, never negative or above it', () => {
    expect(merchantCommissionVnd(100_000, 2_000)).toBe(20_000);
    expect(merchantCommissionVnd(33_333, 2_000)).toBe(6_667);
    expect(merchantCommissionVnd(0, 2_000)).toBe(0);
    expect(merchantCommissionVnd(50_000, 0)).toBe(0);
    expect(merchantCommissionVnd(50_000, 10_000)).toBe(50_000);
  });

  it('customer-unreachable needs the minimum wait since pickup; other reasons do not', () => {
    const pickedAt = new Date('2026-11-06T03:00:00Z');
    const base = { note: null, minWaitMinutes: 10 };
    expect(() =>
      assertFailWaitOver(pickedAt, { ...base, reasonCode: 'CUSTOMER_UNREACHABLE', now: new Date('2026-11-06T03:09:59Z') }),
    ).toThrow(expect.objectContaining({ code: 'FOOD_FAIL_TOO_EARLY' }));
    expect(() =>
      assertFailWaitOver(pickedAt, { ...base, reasonCode: 'CUSTOMER_UNREACHABLE', now: new Date('2026-11-06T03:10:00Z') }),
    ).not.toThrow();
    expect(() =>
      assertFailWaitOver(pickedAt, { ...base, reasonCode: 'CUSTOMER_REFUSED', now: pickedAt }),
    ).not.toThrow();
  });

  it('pickup snapshots the store cash; fail records the reason and runs the hook first', async () => {
    const repo = new MemoryFoodRepository();
    const at = new Date('2026-11-06T03:00:00Z');
    const order = await pickedUp(repo, at);
    expect(order).toMatchObject({ status: 'PICKED_UP', merchantCashVnd: 50_000, pickedUpAt: at });
    await expect(
      repo.fail(order.id, 'driver-1', {
        reasonCode: 'CUSTOMER_REFUSED',
        note: null,
        minWaitMinutes: 10,
        now: at,
      }, async () => {
        throw new Error('hook failed');
      }),
    ).rejects.toThrow('hook failed');
    expect((await repo.findOrder(order.id))?.status).toBe('PICKED_UP');
    const seen: number[] = [];
    const failed = await repo.fail(
      order.id,
      'driver-1',
      { reasonCode: 'WRONG_ADDRESS', note: 'Sai số nhà', minWaitMinutes: 10, now: at },
      async (_tx, view) => {
        seen.push(view.merchantCashVnd ?? 0);
      },
    );
    expect(seen).toEqual([50_000]);
    expect(failed).toMatchObject({ status: 'FAILED', failReason: { code: 'WRONG_ADDRESS', note: 'Sai số nhà' } });
  });
});
