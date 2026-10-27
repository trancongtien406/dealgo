import { describe, expect, it } from 'vitest';
import { MemoryFoodRepository } from './food.repository.js';

describe('MemoryFoodRepository.listReady near filter', () => {
  it('applies the radius before the limit so a new nearby order is not hidden by older far ones', async () => {
    const repo = new MemoryFoodRepository();
    await repo.createFixtureStore('owner-1', [{ name: 'Phở bò', priceVnd: 50_000 }]);
    const store = (await repo.findStoreByOwner('owner-1'))!;
    const placeReady = async (key: string, pickup: { lat: number; lng: number }) => {
      // Pickup is the store pin at placement time, so move the store before each order.
      await repo.updateStoreLocation({ ownerId: 'owner-1', lat: pickup.lat, lng: pickup.lng, addressLabel: key } as never);
      const o = await repo.place({
        customerId: `cust-${key}`,
        storeId: store.id,
        idempotencyKey: key,
        deliveryFareVnd: 15_000,
        items: [{ itemId: store.items[0].id, quantity: 1 }],
        dropoff: { ...pickup, label: key },
        pickup: { ...pickup, label: key },
      } as never);
      await repo.accept(o.id, 'owner-1');
      await repo.markReady(o.id, 'owner-1');
      return o.id;
    };
    const far = await placeReady('far', { lat: 21.0278, lng: 105.8342 }); // Hà Nội, older
    // Distinct createdAt so "older" is deterministic (same-ms ties sort by random UUID).
    await new Promise((resolve) => setTimeout(resolve, 5));
    const near = await placeReady('near', { lat: 16.0544, lng: 108.2022 }); // Đà Nẵng, newer

    expect((await repo.listReady(1)).map((o) => o.id)).toEqual([far]);
    const nearby = await repo.listReady(1, { lat: 16.055, lng: 108.2025, radiusKm: 5 });
    expect(nearby.map((o) => o.id)).toEqual([near]);
  });
});
