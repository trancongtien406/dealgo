import { describe, expect, it } from 'vitest';
import {
  foodCategoryImageKey,
  keyFromFoodCategoryImageUrl,
  slugifyFoodCategory,
  uniqueFoodCategoryCode,
} from './food-category.js';
import { DEFAULT_FOOD_CATEGORIES, MemoryFoodCategoryRepository } from './food-category.repository.js';
import { FoodCategoryService } from './food-category.service.js';

function makeService() {
  const repo = new MemoryFoodCategoryRepository();
  const stored = new Map<string, Buffer>();
  let n = 0;
  const uploads = {
    storeThen: async (
      prefix: string,
      files: Array<{ contentType?: string; contentBase64: string }>,
      fn: (refs: Array<{ key: string; contentType: string }>) => Promise<unknown>,
    ) => {
      n += 1;
      const key = `${prefix}/00000000-0000-4000-8000-${String(n).padStart(12, '0')}.png`;
      stored.set(key, Buffer.from(files[0]!.contentBase64, 'base64'));
      return fn([{ key, contentType: files[0]!.contentType ?? 'image/png' }]);
    },
    discard: async (refs: Array<{ key: string }>) => {
      for (const ref of refs) stored.delete(ref.key);
    },
    read: async ({ key, contentType }: { key: string; contentType: string }) => {
      const body = stored.get(key);
      return body ? { body, contentType } : null;
    },
  } as never;
  return { repo, stored, service: new FoodCategoryService(repo, uploads) };
}

const PNG = Buffer.from('89504e470d0a1a0a', 'hex').toString('base64');

describe('food category codes (DEC-PROD-067)', () => {
  it('slugifies Vietnamese names', () => {
    expect(slugifyFoodCategory('Bún bò Huế')).toBe('bun_bo_hue');
    expect(slugifyFoodCategory('  Đồ uống & Trà ')).toBe('do_uong_tra');
    expect(slugifyFoodCategory('🍜')).toBe('');
    expect(slugifyFoodCategory('a'.repeat(39) + ' b')).toBe('a'.repeat(39));
  });

  it('suffixes taken codes and falls back for empty slugs', () => {
    expect(uniqueFoodCategoryCode('Phở', new Set(['pho']))).toBe('pho_2');
    expect(uniqueFoodCategoryCode('Phở', new Set(['pho', 'pho_2']))).toBe('pho_3');
    expect(uniqueFoodCategoryCode('!!', new Set())).toBe('danh_muc');
  });

  it('only accepts image keys under the category prefix', () => {
    const key = 'food-categories/pho/00000000-0000-4000-8000-000000000001.png';
    expect(foodCategoryImageKey('pho', '00000000-0000-4000-8000-000000000001.png')).toBe(key);
    expect(foodCategoryImageKey('pho', '../x.png')).toBeNull();
    expect(keyFromFoodCategoryImageUrl(`/v1/public/food-categories/images/pho/00000000-0000-4000-8000-000000000001.png`)).toBe(key);
    expect(keyFromFoodCategoryImageUrl('https://evil.example/x.png')).toBeNull();
  });
});

describe('FoodCategoryService', () => {
  it('lists the 9 seeded categories in order, public view hides inactive', async () => {
    const { service } = makeService();
    const ops = await service.listOps();
    expect(ops.items.map((c) => c.code)).toEqual(DEFAULT_FOOD_CATEGORIES.map((c) => c.code));
    expect(ops.items[0]).toMatchObject({ code: 'pho', nameVi: 'Phở', storeCount: 0, active: true });
    await service.update('mart', { active: false }, 'ops-1');
    const pub = await service.listPublic();
    expect(pub.map((c) => c.code)).not.toContain('mart');
    expect(pub[0]).toEqual({
      code: 'pho', nameVi: 'Phở', nameEn: 'Pho', icon: 'soup', tone: 'orange', imageUrl: null,
    });
  });

  it('creates with an auto code at the end of the list and audits it', async () => {
    const { service, repo } = makeService();
    const a = await service.create({ nameVi: 'Bún bò Huế', nameEn: 'Hue beef noodles', icon: 'soup', tone: 'red' }, 'ops-1');
    const b = await service.create({ nameVi: 'Bún bò huế', nameEn: 'Again', icon: 'soup', tone: 'red', active: false }, 'ops-1');
    expect(a).toMatchObject({ code: 'bun_bo_hue', sortOrder: 90, active: true, storeCount: 0 });
    expect(b).toMatchObject({ code: 'bun_bo_hue_2', sortOrder: 100, active: false });
    expect(repo.audits.map((x) => x.action)).toEqual(['FOOD_CATEGORY_CREATE', 'FOOD_CATEGORY_CREATE']);
    expect((await service.listPublic()).map((c) => c.code)).toContain('bun_bo_hue');
  });

  it('skips no-op updates and audits only changed fields', async () => {
    const { service, repo } = makeService();
    await service.update('pho', { nameVi: 'Phở' }, 'ops-1');
    expect(repo.audits).toHaveLength(0);
    const updated = await service.update('pho', { nameVi: 'Phở bò', icon: 'beef' }, 'ops-1');
    expect(updated).toMatchObject({ nameVi: 'Phở bò', icon: 'beef', code: 'pho' });
    expect(repo.audits[0]!.metadata).toEqual({
      changes: { nameVi: { from: 'Phở', to: 'Phở bò' }, icon: { from: 'soup', to: 'beef' } },
    });
    await expect(service.update('nope', { active: false }, 'ops-1')).rejects.toMatchObject({ status: 404 });
  });

  it('refuses to delete a category stores still use', async () => {
    const { service, repo } = makeService();
    repo.counts.set('noodles', 1);
    await expect(service.remove('noodles', 'ops-1')).rejects.toMatchObject({ status: 409 });
    expect((await service.listOps()).items.find((c) => c.code === 'noodles')!.storeCount).toBe(1);
    await expect(service.remove('snack', 'ops-1')).resolves.toEqual({ code: 'snack', deleted: true });
    expect((await service.listOps()).items.map((c) => c.code)).not.toContain('snack');
  });

  it('reorders listed codes first, keeping the rest in order', async () => {
    const { service } = makeService();
    const { items } = await service.reorder(['mart', 'pho', 'mart', 'ghost'], 'ops-1');
    expect(items.map((c) => c.code)).toEqual([
      'mart', 'pho', 'noodles', 'rice', 'banh_mi', 'tea', 'cafe', 'fast_food', 'snack',
    ]);
    expect(items.map((c) => c.sortOrder)).toEqual([0, 10, 20, 30, 40, 50, 60, 70, 80]);
  });

  it('only lets merchants pick active categories', async () => {
    const { service } = makeService();
    await expect(service.requireAssignable('noodles')).resolves.toMatchObject({ code: 'noodles' });
    await service.update('noodles', { active: false }, 'ops-1');
    await expect(service.requireAssignable('noodles')).rejects.toMatchObject({ status: 400 });
    await expect(service.requireAssignable('Bún')).rejects.toMatchObject({ status: 400 });
  });

  it('uploads, serves and removes the category image', async () => {
    const { service, stored } = makeService();
    const up = await service.uploadImage('pho', { contentType: 'image/png', contentBase64: PNG }, 'ops-1');
    expect(up.imageUrl).toMatch(/^\/v1\/public\/food-categories\/images\/pho\/[0-9a-f-]+\.png$/);
    const file = up.imageUrl!.split('/').pop()!;
    await expect(service.readImage('pho', file)).resolves.toMatchObject({ contentType: 'image/png' });
    await expect(service.readImage('rice', file)).rejects.toMatchObject({ status: 404 });
    await expect(
      service.uploadImage('pho', { contentType: 'image/gif', contentBase64: PNG }, 'ops-1'),
    ).rejects.toMatchObject({ status: 400 });
    const cleared = await service.update('pho', { imageUrl: null }, 'ops-1');
    expect(cleared.imageUrl).toBeNull();
    expect(stored.size).toBe(0);
  });
});
