/**
 * DEC-PROD-067 — admin-managed food store categories: pure rules (code
 * generation, icon/tone allowlists, image paths). No Nest / Prisma imports so
 * specs, the repository and the service can share them.
 */
import { HttpException } from '@nestjs/common';

/** Lucide icon keys the app knows how to draw (mobile `DealGoIcons.foodCategory`). */
export const FOOD_CATEGORY_ICONS = [
  'soup',
  'cooking-pot',
  'utensils',
  'sandwich',
  'cup-soda',
  'coffee',
  'hamburger',
  'pizza',
  'drumstick',
  'beef',
  'fish',
  'salad',
  'egg-fried',
  'croissant',
  'cake-slice',
  'cookie',
  'ice-cream-cone',
  'popcorn',
  'beer',
  'apple',
  'wheat',
  'shopping-cart',
  'store',
] as const;
export type FoodCategoryIcon = (typeof FOOD_CATEGORY_ICONS)[number];

/** Colour keys for the round tile (mobile `foodCategoryTone`, admin swatches). */
export const FOOD_CATEGORY_TONES = [
  'orange',
  'amber',
  'red',
  'pink',
  'purple',
  'indigo',
  'blue',
  'green',
  'brown',
] as const;
export type FoodCategoryTone = (typeof FOOD_CATEGORY_TONES)[number];

/** Seconds clients / CDNs may cache the public list (the app also keeps its own copy). */
export const FOOD_CATEGORY_PUBLIC_MAX_AGE_S = 300;

export type FoodCategory = {
  code: string;
  nameVi: string;
  nameEn: string;
  icon: FoodCategoryIcon;
  tone: FoodCategoryTone;
  imageUrl: string | null;
  sortOrder: number;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
};

export function foodCategoryError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ errorCode, message }, status);
}

export const FOOD_CATEGORY_CODE_RE = /^[a-z0-9]+(?:_[a-z0-9]+)*$/;
const CODE_MAX = 40;

/** "Bún bò Huế" → "bun_bo_hue"; empty when the name has no letters or digits. */
export function slugifyFoodCategory(name: string): string {
  return name
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, CODE_MAX)
    .replace(/_+$/g, '');
}

/** Slug of the name, suffixed `_2`, `_3`… until it is unused. */
export function uniqueFoodCategoryCode(name: string, taken: ReadonlySet<string>): string {
  const base = slugifyFoodCategory(name) || 'danh_muc';
  if (!taken.has(base)) {
    return base;
  }
  for (let n = 2; ; n += 1) {
    const candidate = `${base}_${n}`;
    if (!taken.has(candidate)) {
      return candidate;
    }
  }
}

export function compareFoodCategories(a: FoodCategory, b: FoodCategory): number {
  return a.sortOrder - b.sortOrder || a.code.localeCompare(b.code);
}

// ---- images -----------------------------------------------------------------

export const FOOD_CATEGORY_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const FOOD_CATEGORY_IMAGE_PREFIX = '/v1/public/food-categories/images';
export const FOOD_CATEGORY_STORAGE_PREFIX = 'food-categories';

const FILE_RE = /^[0-9a-f-]{36}\.(jpg|png|webp)$/;

export function isFoodCategoryCode(code: string): boolean {
  return code.length <= 64 && FOOD_CATEGORY_CODE_RE.test(code);
}

export function foodCategoryImagePath(code: string, key: string): string {
  const file = key.slice(`${FOOD_CATEGORY_STORAGE_PREFIX}/${code}/`.length);
  return `${FOOD_CATEGORY_IMAGE_PREFIX}/${code}/${file}`;
}

export function foodCategoryImageKey(code: string, file: string): string | null {
  if (!isFoodCategoryCode(code) || !FILE_RE.test(file)) {
    return null;
  }
  return `${FOOD_CATEGORY_STORAGE_PREFIX}/${code}/${file}`;
}

export function keyFromFoodCategoryImageUrl(url: string | null | undefined): string | null {
  if (!url?.startsWith(`${FOOD_CATEGORY_IMAGE_PREFIX}/`)) {
    return null;
  }
  const [code, file, ...extra] = url.slice(FOOD_CATEGORY_IMAGE_PREFIX.length + 1).split('/');
  if (!code || !file || extra.length > 0) {
    return null;
  }
  return foodCategoryImageKey(code, file);
}

export function resolveFoodCategoryImagePayload(input: {
  contentBase64?: string;
  dataUrl?: string;
  contentType?: string;
}): { base64: string; contentType?: string } | null {
  if (typeof input.dataUrl === 'string' && input.dataUrl.trim()) {
    const match = /^data:([^;,]+)?;base64,(.+)$/i.exec(input.dataUrl.trim());
    return match ? { contentType: match[1] || input.contentType, base64: match[2]! } : null;
  }
  if (typeof input.contentBase64 === 'string' && input.contentBase64.trim()) {
    return { contentType: input.contentType, base64: input.contentBase64.trim() };
  }
  return null;
}
