import { describe, expect, it } from 'vitest';
import {
  aggregateStoreCategories,
  filterStoreCategories,
  MemoryFoodRepository,
  slugifyStoreCategory,
} from '../food-order/food.repository.js';

describe('ops catalog categories aggregation', () => {
  it('slugifies Vietnamese category names', () => {
    expect(slugifyStoreCategory('Đồ uống')).toBe('do-uong');
    expect(slugifyStoreCategory('Khác')).toBe('khac');
  });

  it('aggregates null categories as Khác and counts items', () => {
    const items = aggregateStoreCategories([
      { category: 'pho', itemCount: 2 },
      { category: 'Pho', itemCount: 1 },
      { category: null, itemCount: 4 },
      { category: '  ', itemCount: 1 },
    ]);

    expect(items).toEqual([
      expect.objectContaining({
        code: 'khac',
        name: 'Khác',
        storeCount: 2,
        itemCount: 5,
        status: 'ACTIVE',
      }),
      expect.objectContaining({
        code: 'pho',
        name: 'pho',
        storeCount: 2,
        itemCount: 3,
        status: 'ACTIVE',
      }),
    ]);
  });

  it('filters and paginates category list', () => {
    const page = filterStoreCategories(
      aggregateStoreCategories([
        { category: 'pho', itemCount: 1 },
        { category: 'coffee', itemCount: 2 },
        { category: 'bun', itemCount: 3 },
      ]),
      { page: 1, limit: 2, q: 'o' },
    );

    expect(page.total).toBe(2);
    expect(page.items).toHaveLength(2);
    expect(page.items.map((i) => i.code).sort()).toEqual(['coffee', 'pho']);
  });

  it('lists categories from MemoryFoodRepository fixture store', async () => {
    const repo = new MemoryFoodRepository();
    await repo.createFixtureStore('owner-1', [
      { name: 'Bún bò', priceVnd: 50_000 },
      { name: 'Trà', priceVnd: 20_000 },
    ]);

    const page = await repo.listStoreCategories({ page: 1, limit: 20 });
    expect(page.total).toBe(1);
    expect(page.items[0]).toEqual({
      code: 'pho',
      name: 'pho',
      slug: 'pho',
      storeCount: 1,
      itemCount: 2,
      status: 'ACTIVE',
    });

    await expect(repo.findStoreCategoryByCode('pho')).resolves.toEqual(page.items[0]);
    await expect(repo.findStoreCategoryByCode('missing')).resolves.toBeNull();
  });
});
