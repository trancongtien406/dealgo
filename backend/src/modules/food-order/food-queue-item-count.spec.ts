import { describe, expect, it } from 'vitest';
import { MemoryFoodRepository } from './food.repository.js';

describe('merchant queue item count (QA M3)', () => {
  it('counts dishes by quantity, not by line', async () => {
    const food = new MemoryFoodRepository();
    await food.createFixtureStore('owner-1', [
      { name: 'Phở bò', priceVnd: 50_000 },
      { name: 'Trà đá', priceVnd: 5_000 },
    ]);
    const store = (await food.findStoreByOwner('owner-1'))!;
    await food.place({
      customerId: 'cust-1',
      storeId: store.id,
      idempotencyKey: 'k1',
      items: [
        { itemId: store.items[0].id, quantity: 2 },
        { itemId: store.items[1].id, quantity: 3 },
      ],
      dropoff: { lat: 16.05, lng: 108.2, label: 'Hải Châu' },
      deliveryFareVnd: 15_000,
    });
    const [row] = await food.listQueue('owner-1');
    expect(row.lineCount).toBe(2);
    expect(row.itemCount).toBe(5);
  });
});
