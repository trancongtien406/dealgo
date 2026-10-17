import { describe, expect, it } from 'vitest';
import { MemoryFoodRepository } from './food.repository.js';

describe('MemoryFoodRepository', () => {
  const makeStoreAndItems = async () => {
    const repo = new MemoryFoodRepository();
    await repo.createFixtureStore('owner-1', [
      { name: 'Phở bò', priceVnd: 50_000 },
      { name: 'Trà đá', priceVnd: 5_000 },
    ]);
    const store = (await repo.findStoreByOwner('owner-1'))!;
    return { repo, store };
  };

  describe('catalog and store', () => {
    it('initializes fixture store and lists items', async () => {
      const { store } = await makeStoreAndItems();
      expect(store.id).toBeDefined();
      expect(store.items).toHaveLength(2);
      expect(store.items[0].name).toBe('Phở bò');
    });

    it('creates, updates and toggles item availability', async () => {
      const { repo } = await makeStoreAndItems();

      const newItem = await repo.createItem({
        ownerId: 'owner-1',
        name: 'Bánh mì',
        priceVnd: 25_000,
        available: true,
      });
      expect(newItem.name).toBe('Bánh mì');

      const updated = await repo.updateItem({
        ownerId: 'owner-1',
        itemId: newItem.id,
        priceVnd: 30_000,
      });
      expect(updated.priceVnd).toBe(30_000);

      const toggled = await repo.setItemAvailability({
        ownerId: 'owner-1',
        itemId: newItem.id,
        available: false,
      });
      expect(toggled.available).toBe(false);
    });
  });

  describe('order placement and full delivery lifecycle', () => {
    it('progresses order from PLACED -> PREPARING -> READY -> ASSIGNED -> PICKED_UP -> DELIVERED', async () => {
      const { repo, store } = await makeStoreAndItems();

      // 1. Customer places order
      const placed = await repo.place({
        customerId: 'cust-1',
        storeId: store.id,
        idempotencyKey: 'food-idem-1',
        deliveryFareVnd: 15_000,
        items: [
          {
            itemId: store.items[0].id,
            quantity: 2,
          },
        ],
        dropoff: { lat: 10.7769, lng: 106.7009, label: 'Ben Thanh, D1' },
      });

      expect(placed.status).toBe('PLACED');
      expect(placed.subtotalVnd).toBe(100_000);
      expect(placed.totalVnd).toBe(115_000);

      // 2. Merchant accepts -> PREPARING
      const preparing = await repo.accept(placed.id, 'owner-1');
      expect(preparing.status).toBe('PREPARING');

      // 3. Merchant marks READY
      const ready = await repo.markReady(placed.id, 'owner-1');
      expect(ready.status).toBe('READY');

      // 4. Ready list is visible to drivers
      const readyList = await repo.listReady();
      expect(readyList.some((r) => r.id === placed.id)).toBe(true);

      // 5. Driver claims -> ASSIGNED
      const assigned = await repo.claim(placed.id, 'driver-1', 2);
      expect(assigned.status).toBe('ASSIGNED');
      expect(assigned.assignedDriverId).toBe('driver-1');

      // 6. Driver picks up -> PICKED_UP
      const pickedUp = await repo.pickup(placed.id, 'driver-1');
      expect(pickedUp.status).toBe('PICKED_UP');

      // 7. Driver delivers -> DELIVERED
      const delivered = await repo.deliver(placed.id, 'driver-1');
      expect(delivered.status).toBe('DELIVERED');
    });
  });

  describe('cancellation rules', () => {
    it('customer can cancel when PLACED but cannot cancel once PREPARING', async () => {
      const { repo, store } = await makeStoreAndItems();

      const order1 = await repo.place({
        customerId: 'cust-1',
        storeId: store.id,
        idempotencyKey: 'food-idem-cancel-1',
        deliveryFareVnd: 15_000,
        items: [{ itemId: store.items[0].id, quantity: 1 }],
        dropoff: { lat: 10.7769, lng: 106.7009, label: 'Ben Thanh, D1' },
      });

      const cancelled = await repo.cancel(order1.id, 'cust-1');
      expect(cancelled.status).toBe('CANCELLED');

      const order2 = await repo.place({
        customerId: 'cust-1',
        storeId: store.id,
        idempotencyKey: 'food-idem-cancel-2',
        deliveryFareVnd: 15_000,
        items: [{ itemId: store.items[0].id, quantity: 1 }],
        dropoff: { lat: 10.7769, lng: 106.7009, label: 'Ben Thanh, D1' },
      });

      await repo.accept(order2.id, 'owner-1');

      await expect(repo.cancel(order2.id, 'cust-1')).rejects.toThrow();
    });

    it('ops intervention can cancel or reassign an assigned order', async () => {
      const { repo, store } = await makeStoreAndItems();

      const order = await repo.place({
        customerId: 'cust-1',
        storeId: store.id,
        idempotencyKey: 'food-idem-ops-1',
        deliveryFareVnd: 15_000,
        items: [{ itemId: store.items[0].id, quantity: 1 }],
        dropoff: { lat: 10.7769, lng: 106.7009, label: 'Ben Thanh, D1' },
      });

      await repo.accept(order.id, 'owner-1');
      await repo.markReady(order.id, 'owner-1');
      await repo.claim(order.id, 'driver-1', 2);

      const reassigned = await repo.opsReassign(order.id, 'admin-ops', 'Driver bike broke down');
      expect(reassigned.order.status).toBe('READY');
      expect(reassigned.order.assignedDriverId).toBeNull();
      expect(reassigned.auditId).toBeDefined();
    });
  });
});
