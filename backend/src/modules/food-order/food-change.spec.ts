import { describe, expect, it } from 'vitest';
import { foodOrderChangeNotifications } from '../communication/notification/notification-audience.js';
import { MemoryFoodRepository, planFoodOrderChange } from './food.repository.js';

const dropoff = { lat: 16.06, lng: 108.22, label: 'Hải Châu' };

async function placed(repo: MemoryFoodRepository, key = 'change') {
  await repo.createFixtureStore('owner-1', [
    { name: 'Phở bò', priceVnd: 50_000 },
    { name: 'Trà đá', priceVnd: 5_000 },
  ]);
  const store = (await repo.findStoreByOwner('owner-1'))!;
  return repo.place({
    customerId: 'cust-1',
    storeId: store.id,
    idempotencyKey: key,
    deliveryFareVnd: 15_000,
    items: [
      { itemId: store.items[0].id, quantity: 2 },
      { itemId: store.items[1].id, quantity: 1 },
    ],
    dropoff,
  });
}

const soon = () => new Date(Date.now() + 5 * 60_000);

describe('Merchant edits an order, customer confirms', () => {
  it('prices an edit: lower quantities / removals only, discount capped, never empty', () => {
    const order = {
      subtotalVnd: 105_000,
      discountVnd: 80_000,
      deliveryFareVnd: 15_000,
      lines: [
        { id: 'a', itemId: 'i1', name: 'Phở', unitPriceVnd: 50_000, quantity: 2, imageUrl: null, note: null, options: [] },
        { id: 'b', itemId: 'i2', name: 'Trà', unitPriceVnd: 5_000, quantity: 1, imageUrl: null, note: null, options: [] },
      ],
    };
    expect(planFoodOrderChange(order, [{ lineId: 'a', toQuantity: 1 }])).toMatchObject({
      oldSubtotalVnd: 105_000,
      newSubtotalVnd: 55_000,
      newDiscountVnd: 55_000,
      newTotalVnd: 15_000,
    });
    for (const bad of [
      [],
      [{ lineId: 'a', toQuantity: 2 }],
      [{ lineId: 'a', toQuantity: 3 }],
      [{ lineId: 'zz', toQuantity: 0 }],
      [{ lineId: 'a', toQuantity: 1 }, { lineId: 'a', toQuantity: 0 }],
      [{ lineId: 'a', toQuantity: 0 }, { lineId: 'b', toQuantity: 0 }],
    ]) {
      expect(() => planFoodOrderChange(order, bad)).toThrow(expect.objectContaining({ code: 'FOOD_CHANGE_INVALID' }));
    }
  });

  it('accept applies the new lines and totals; ready is blocked while pending; one pending at a time', async () => {
    const repo = new MemoryFoodRepository();
    const order = await placed(repo);
    await repo.accept(order.id, 'owner-1');
    const [pho, tra] = order.lines;
    const { change } = await repo.proposeChange({
      orderId: order.id,
      ownerId: 'owner-1',
      reasonCode: 'OUT_OF_STOCK',
      note: null,
      lines: [{ lineId: tra.id, toQuantity: 0 }],
      expiresAt: soon(),
    });
    expect(change).toMatchObject({ status: 'PENDING', newSubtotalVnd: 100_000, newTotalVnd: 115_000 });
    await expect(repo.markReady(order.id, 'owner-1')).rejects.toMatchObject({ code: 'FOOD_CHANGE_PENDING' });
    await expect(
      repo.proposeChange({
        orderId: order.id,
        ownerId: 'owner-1',
        reasonCode: 'OUT_OF_STOCK',
        note: null,
        lines: [{ lineId: pho.id, toQuantity: 1 }],
        expiresAt: soon(),
      }),
    ).rejects.toMatchObject({ code: 'FOOD_CHANGE_PENDING' });
    await expect(repo.respondChange(order.id, 'someone-else', change.id, true, new Date())).rejects.toMatchObject({
      code: 'FOOD_ORDER_NOT_FOUND',
    });
    const done = await repo.respondChange(order.id, 'cust-1', change.id, true, new Date());
    expect(done.change.status).toBe('ACCEPTED');
    expect(done.order).toMatchObject({ status: 'PREPARING', subtotalVnd: 100_000, totalVnd: 115_000 });
    expect(done.order.lines.map((line) => [line.name, line.quantity])).toEqual([['Phở bò', 2]]);
    await expect(repo.respondChange(order.id, 'cust-1', change.id, false, new Date())).rejects.toMatchObject({
      code: 'FOOD_STATUS_CONFLICT',
    });
    expect((await repo.markReady(order.id, 'owner-1')).status).toBe('READY');
    await expect(
      repo.proposeChange({
        orderId: order.id,
        ownerId: 'owner-1',
        reasonCode: 'OTHER',
        note: 'x',
        lines: [{ lineId: pho.id, toQuantity: 1 }],
        expiresAt: soon(),
      }),
    ).rejects.toMatchObject({ code: 'FOOD_STATUS_CONFLICT' });
  });

  it('decline cancels without fee (CUSTOMER, CHANGE_REJECTED); silence expires to SYSTEM cancel', async () => {
    const repo = new MemoryFoodRepository();
    const first = await placed(repo, 'change-a');
    const { change } = await repo.proposeChange({
      orderId: first.id,
      ownerId: 'owner-1',
      reasonCode: 'NOT_ENOUGH_PORTIONS',
      note: null,
      lines: [{ lineId: first.lines[0].id, toQuantity: 1 }],
      expiresAt: soon(),
    });
    const declined = await repo.respondChange(first.id, 'cust-1', change.id, false, new Date());
    expect(declined.order).toMatchObject({
      status: 'CANCELLED',
      cancelledBy: 'CUSTOMER',
      cancelReason: { code: 'CHANGE_REJECTED' },
    });

    const second = await placed(repo, 'change-b');
    const pending = await repo.proposeChange({
      orderId: second.id,
      ownerId: 'owner-1',
      reasonCode: 'OUT_OF_STOCK',
      note: null,
      lines: [{ lineId: second.lines[1].id, toQuantity: 0 }],
      expiresAt: new Date(Date.now() + 60_000),
    });
    expect(await repo.expireChanges(new Date())).toEqual([]);
    const later = new Date(Date.now() + 2 * 60_000);
    await expect(repo.respondChange(second.id, 'cust-1', pending.change.id, true, later)).rejects.toMatchObject({
      code: 'FOOD_STATUS_CONFLICT',
    });
    expect(await repo.expireChanges(later)).toEqual([second.id]);
    expect(await repo.findOrder(second.id)).toMatchObject({
      status: 'CANCELLED',
      cancelledBy: 'SYSTEM',
      cancelReason: { code: 'CHANGE_EXPIRED' },
    });
    expect((await repo.latestChange(second.id))?.status).toBe('EXPIRED');
  });

  it('push copy: customer asked to confirm, store told when accepted', () => {
    const roles = { customerId: 'c', merchantId: 'm', driverId: null };
    expect(foodOrderChangeNotifications('0000-abcd', 'PENDING', roles)).toEqual([
      expect.objectContaining({ userId: 'c', category: 'FOOD' }),
    ]);
    expect(foodOrderChangeNotifications('0000-abcd', 'ACCEPTED', roles)).toEqual([
      expect.objectContaining({ userId: 'm' }),
    ]);
    expect(foodOrderChangeNotifications('0000-abcd', 'EXPIRED', roles)).toEqual([]);
  });
});
