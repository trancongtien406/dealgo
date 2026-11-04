import { describe, expect, it } from 'vitest';
import {
  MemoryFoodRepository,
  pickFeaturedItems,
  shownOriginalPrice,
  snapshotFoodLines,
  type StoreFeaturedItem,
} from './food.repository.js';

const dropoff = { lat: 16.05, lng: 108.2, label: 'Hải Châu' };

function dish(id: string, soldCount: number, addedAt: string): StoreFeaturedItem {
  return { id, name: id, priceVnd: 30_000, originalPriceVnd: null, imageUrl: null, soldCount, addedAt };
}

async function setup() {
  const food = new MemoryFoodRepository();
  await food.createFixtureStore('owner-1', [{ name: 'Phở bò', priceVnd: 50_000 }]);
  const store = (await food.findStoreByOwner('owner-1'))!;
  return { food, store };
}

describe('food browse extras', () => {
  it('keeps the list price only while it is above the selling price', () => {
    expect(shownOriginalPrice(50_000, 65_000)).toBe(65_000);
    expect(shownOriginalPrice(50_000, 50_000)).toBeNull();
    expect(shownOriginalPrice(50_000, null)).toBeNull();
  });

  it('features the top sellers then the newest dish', () => {
    const picked = pickFeaturedItems([
      dish('a', 0, '2026-10-01T00:00:00.000Z'),
      dish('b', 12, '2026-09-01T00:00:00.000Z'),
      dish('c', 30, '2026-08-01T00:00:00.000Z'),
      dish('d', 4, '2026-07-01T00:00:00.000Z'),
    ]);
    expect(picked.map((item) => item.id)).toEqual(['c', 'b', 'a']);
    expect(pickFeaturedItems([dish('a', 3, '2026-10-01T00:00:00.000Z')]).map((i) => i.id)).toEqual(['a']);
    expect(pickFeaturedItems([])).toEqual([]);
  });

  it('stores the original price and drops it when the price passes it', async () => {
    const { food, store } = await setup();
    const created = await food.createItem({
      ownerId: 'owner-1',
      name: 'Bún bò',
      priceVnd: 45_000,
      originalPriceVnd: 55_000,
    });
    expect(created.originalPriceVnd).toBe(55_000);
    await food.setCatalogModeration(created.id, 'APPROVED');
    expect(created.addedAt).not.toBeNull();
    const raised = await food.updateItem({ ownerId: 'owner-1', itemId: created.id, priceVnd: 60_000 });
    expect(raised.originalPriceVnd).toBeNull();
    const featured = (await food.listFeaturedItems([store.id])).get(store.id) ?? [];
    expect(featured.map((item) => item.id)).toContain(created.id);
  });

  it('rejects an order under the store minimum', async () => {
    const { food, store } = await setup();
    await food.updateStoreProfile({ ownerId: 'owner-1', minOrderVnd: 80_000 });
    expect((await food.findStore(store.id))!.minOrderVnd).toBe(80_000);
    const place = (quantity: number, key: string) =>
      food.place({
        customerId: 'cust-1',
        storeId: store.id,
        idempotencyKey: key,
        items: [{ itemId: store.items[0].id, quantity }],
        dropoff,
        deliveryFareVnd: 15_000,
      });
    await expect(place(1, 'k1')).rejects.toMatchObject({ code: 'FOOD_MIN_ORDER_NOT_MET' });
    const order = await place(2, 'k2');
    expect(order.subtotalVnd).toBe(100_000);
  });
});

describe('item moderation can be disabled per platform setting', () => {
  it('creates APPROVED dishes when the service passes the disabled verdict', async () => {
    const food = new MemoryFoodRepository();
    await food.createStore('owner-auto', 'Quán Tự Duyệt', []);
    const item = await food.createItem({
      ownerId: 'owner-auto',
      name: 'Phở',
      priceVnd: 40_000,
      moderationStatus: 'APPROVED',
    });
    expect(item.moderationStatus).toBe('APPROVED');
    expect(item.available).toBe(true);
  });

  it('skips the approval gate only when the caller asks for it', async () => {
    const food = new MemoryFoodRepository();
    await food.createStore('owner-gate', 'Quán Chờ Duyệt', []);
    const item = await food.createItem({
      ownerId: 'owner-gate',
      name: 'Phở',
      priceVnd: 40_000,
    });
    const view = { ...item, available: true, moderationStatus: 'PENDING' as const };
    const requested = [{ itemId: item.id, quantity: 1 }];
    expect(() => snapshotFoodLines([view], requested)).toThrow();
    expect(snapshotFoodLines([view], requested, false)).toHaveLength(1);
  });

  it('hides menu sections that only hold unapproved dishes', async () => {
    const food = new MemoryFoodRepository();
    const store = await food.createStore('owner-sections', 'Quán Mục Lục', []);
    const category = await food.createMenuCategory({
      ownerId: 'owner-sections',
      name: 'Món chính',
    });
    const item = await food.createItem({
      ownerId: 'owner-sections',
      name: 'Phở',
      priceVnd: 40_000,
      menuCategoryId: category.id,
    });
    expect(await food.listStoreMenuSections(store.id)).toEqual([]);
    expect(
      (await food.listStoreMenuSections(store.id, false)).map((row) => row.id),
    ).toEqual([category.id]);
    await food.setCatalogModeration(item.id, 'APPROVED');
    expect(
      (await food.listStoreMenuSections(store.id)).map((row) => row.id),
    ).toEqual([category.id]);
  });
});

describe('catalog moderation gates sale (FOOD-001)', () => {
  it('new items wait for approval, availability never self-approves, and only APPROVED dishes can be ordered', async () => {
    const { MemoryFoodRepository } = await import('./food.repository.js');
    const food = new MemoryFoodRepository();
    const store = await food.createStore('owner-mod', 'Quán Duyệt', []);
    const item = await food.createItem({ ownerId: 'owner-mod', name: 'Phở', priceVnd: 40_000 });
    await expect(
      food.setItemAvailability({ ownerId: 'owner-mod', itemId: item.id, available: true }),
    ).rejects.toMatchObject({ code: 'FOOD_ITEM_NOT_APPROVED' });
    await food.setCatalogModeration(item.id, 'REJECTED');
    await expect(
      food.setItemAvailability({ ownerId: 'owner-mod', itemId: item.id, available: true }),
    ).rejects.toMatchObject({ code: 'FOOD_ITEM_NOT_APPROVED' });
    // Turning a dish off is always allowed and keeps the moderation verdict.
    const off = await food.setItemAvailability({ ownerId: 'owner-mod', itemId: item.id, available: false });
    expect(off.available).toBe(false);
    const { snapshotFoodLines } = await import('./food.repository.js');
    const view = { ...item, available: true, moderationStatus: 'PENDING' };
    expect(() => snapshotFoodLines([view], [{ itemId: item.id, quantity: 1 }])).toThrow();
    expect(snapshotFoodLines([{ ...view, moderationStatus: 'APPROVED' }], [{ itemId: item.id, quantity: 1 }])).toHaveLength(1);
    await food.setCatalogModeration(item.id, 'APPROVED');
    const on = await food.setItemAvailability({ ownerId: 'owner-mod', itemId: item.id, available: true });
    expect(on.available).toBe(true);
    expect(store.id).toBeTruthy();
  });
});
