import { describe, expect, it } from 'vitest';
import { counterCeilingVnd, MemoryFoodRepository } from './food.repository.js';

const early = { leadMinutes: 5, now: new Date() };
const counter = (repo: MemoryFoodRepository, orderId: string, driverId: string, amountVnd: number, extra: Partial<{ maxEdits: number; expiresAt: Date }> = {}) =>
  repo.submitDeliveryOffer({
    orderId,
    driverId,
    amountVnd,
    expiresAt: extra.expiresAt ?? new Date(Date.now() + 120_000),
    maxEdits: extra.maxEdits ?? 2,
    counterMaxPercent: 150,
    maxFareVnd: 100_000,
    early,
  });

async function readyOrder() {
  const repo = new MemoryFoodRepository();
  await repo.createFixtureStore('owner-1', [{ name: 'Phở bò', priceVnd: 50_000 }]);
  const store = (await repo.findStoreByOwner('owner-1'))!;
  const order = await repo.place({
    customerId: 'cust-1',
    storeId: store.id,
    idempotencyKey: 'fee-1',
    deliveryFareVnd: 15_000,
    suggestedDeliveryFareVnd: 16_000,
    items: [{ itemId: store.items[0].id, quantity: 1 }],
    dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
  });
  await repo.accept(order.id, 'owner-1');
  await repo.markReady(order.id, 'owner-1');
  return { repo, orderId: order.id };
}

describe('food delivery-fee negotiation (memory repo)', () => {
  it('stores the suggestion apart from the customer offer', async () => {
    const { repo, orderId } = await readyOrder();
    const order = (await repo.findOrder(orderId))!;
    expect(order.suggestedDeliveryFareVnd).toBe(16_000);
    expect(order.deliveryFareVnd).toBe(15_000);
    expect(order.totalVnd).toBe(65_000);
    expect(order.deliveryFareAgreedAt ?? null).toBeNull();
  });

  it('counter must be above the offer and within the cap', async () => {
    const { repo, orderId } = await readyOrder();
    await expect(counter(repo, orderId, 'drv-a', 15_000)).rejects.toMatchObject({ code: 'FOOD_OFFER_AMOUNT_INVALID' });
    await expect(counter(repo, orderId, 'drv-a', 23_000)).rejects.toMatchObject({ code: 'FOOD_OFFER_AMOUNT_INVALID' });
    expect(counterCeilingVnd(15_000, 150, 100_000)).toBe(22_500);
    const offer = await counter(repo, orderId, 'drv-a', 20_000);
    expect(offer.status).toBe('PENDING');
  });

  it('limits counter edits per driver', async () => {
    const { repo, orderId } = await readyOrder();
    await counter(repo, orderId, 'drv-a', 18_000, { maxEdits: 1 });
    const edited = await counter(repo, orderId, 'drv-a', 19_000, { maxEdits: 1 });
    expect(edited.editCount).toBe(1);
    await expect(counter(repo, orderId, 'drv-a', 20_000, { maxEdits: 1 })).rejects.toMatchObject({ code: 'FOOD_OFFER_EDIT_LIMIT' });
  });

  it('selecting a counter assigns that driver at the agreed fee; other offers lose', async () => {
    const { repo, orderId } = await readyOrder();
    const a = await counter(repo, orderId, 'drv-a', 20_000);
    await counter(repo, orderId, 'drv-b', 18_000);
    const claimed = await repo.claim(orderId, 'drv-a', 2, early, { offerId: a.id, customerId: 'cust-1', now: new Date() });
    expect(claimed.assignedDriverId).toBe('drv-a');
    expect(claimed.deliveryFareVnd).toBe(20_000);
    expect(claimed.totalVnd).toBe(70_000);
    expect(claimed.deliveryFareAgreedAt).toBeInstanceOf(Date);
    const statuses = Object.fromEntries((await repo.listDeliveryOffers(orderId)).map((o) => [o.driverId, o.status]));
    expect(statuses).toEqual({ 'drv-a': 'SELECTED', 'drv-b': 'LOST' });
  });

  it('a plain claim accepts the customer offer and closes pending counters', async () => {
    const { repo, orderId } = await readyOrder();
    await counter(repo, orderId, 'drv-b', 18_000);
    const claimed = await repo.claim(orderId, 'drv-a', 2, early);
    expect(claimed.deliveryFareVnd).toBe(15_000);
    expect((await repo.listDeliveryOffers(orderId))[0].status).toBe('LOST');
  });

  it('rejects selecting an expired or withdrawn counter', async () => {
    const { repo, orderId } = await readyOrder();
    const old = await counter(repo, orderId, 'drv-a', 20_000, { expiresAt: new Date(Date.now() - 1000) });
    await expect(
      repo.claim(orderId, 'drv-a', 2, early, { offerId: old.id, customerId: 'cust-1', now: new Date() }),
    ).rejects.toBeTruthy();
    const b = await counter(repo, orderId, 'drv-b', 19_000);
    await repo.withdrawDeliveryOffer(orderId, 'drv-b');
    await expect(
      repo.claim(orderId, 'drv-b', 2, early, { offerId: b.id, customerId: 'cust-1', now: new Date() }),
    ).rejects.toBeTruthy();
  });

  it('customer raise updates totals, is capped, and locks once assigned', async () => {
    const { repo, orderId } = await readyOrder();
    const raised = await repo.raiseDeliveryFare({ orderId, customerId: 'cust-1', amountVnd: 18_000, maxRaises: 1 });
    expect(raised.deliveryFareVnd).toBe(18_000);
    expect(raised.totalVnd).toBe(68_000);
    await expect(repo.raiseDeliveryFare({ orderId, customerId: 'cust-1', amountVnd: 19_000, maxRaises: 1 })).rejects.toMatchObject({ code: 'FOOD_FARE_RAISE_LIMIT' });
    await repo.claim(orderId, 'drv-a', 2, early);
    await expect(repo.raiseDeliveryFare({ orderId, customerId: 'cust-1', amountVnd: 20_000, maxRaises: 5 })).rejects.toMatchObject({ code: 'FOOD_FARE_LOCKED' });
  });
});
