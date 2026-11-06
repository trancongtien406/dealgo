import { Inject, Injectable } from '@nestjs/common';
import { DocumentStoreService } from '../../platform/storage/document-store.service.js';
import { FOOD_CATEGORY_REPOSITORY } from './food-category.constants.js';
import type {
  CreateFoodCategoryDto,
  PatchFoodCategoryDto,
  UploadFoodCategoryImageDto,
} from './food-category.dto.js';
import {
  FOOD_CATEGORY_IMAGE_TYPES,
  FOOD_CATEGORY_STORAGE_PREFIX,
  foodCategoryError,
  foodCategoryImageKey,
  foodCategoryImagePath,
  isFoodCategoryCode,
  keyFromFoodCategoryImageUrl,
  resolveFoodCategoryImagePayload,
  uniqueFoodCategoryCode,
  type FoodCategory,
  type FoodCategoryIcon,
  type FoodCategoryTone,
} from './food-category.js';
import type { FoodCategoryFields, FoodCategoryRepository } from './food-category.repository.js';

export type PublicFoodCategoryView = {
  code: string;
  nameVi: string;
  nameEn: string;
  icon: FoodCategoryIcon;
  tone: FoodCategoryTone;
  imageUrl: string | null;
};

export type OpsFoodCategoryView = PublicFoodCategoryView & {
  sortOrder: number;
  active: boolean;
  storeCount: number;
  createdAt: string;
  updatedAt: string;
};

const PUBLIC_CACHE_MS = 30_000;
const NOT_FOUND = () => foodCategoryError(404, 'FOOD_CATEGORY_NOT_FOUND', 'Food category not found');
const IMAGE_TYPE = () =>
  foodCategoryError(400, 'FOOD_CATEGORY_IMAGE_TYPE', 'Image must be JPEG, PNG or WebP');

function toPublic(row: FoodCategory): PublicFoodCategoryView {
  return {
    code: row.code,
    nameVi: row.nameVi,
    nameEn: row.nameEn,
    icon: row.icon,
    tone: row.tone,
    imageUrl: row.imageUrl,
  };
}

/** DEC-PROD-067 — store categories: ops CRUD, public list, merchant validation. */
@Injectable()
export class FoodCategoryService {
  private cache: { at: number; rows: FoodCategory[] } | null = null;

  constructor(
    @Inject(FOOD_CATEGORY_REPOSITORY) private readonly categories: FoodCategoryRepository,
    private readonly uploads: DocumentStoreService,
  ) {}

  // ---- public -----------------------------------------------------------

  async listPublic(): Promise<PublicFoodCategoryView[]> {
    return (await this.cachedActive()).map(toPublic);
  }

  /** Throws 400 unless `code` names an active category (merchant store settings). */
  async requireAssignable(code: string): Promise<FoodCategory> {
    const row = isFoodCategoryCode(code) ? await this.categories.find(code) : null;
    if (!row || !row.active) {
      throw foodCategoryError(400, 'FOOD_CATEGORY_INVALID', 'Choose one of the listed store categories');
    }
    return row;
  }

  async readImage(
    code: string,
    file: string,
    width: number | null = null,
  ): Promise<{ body: Buffer; contentType: string }> {
    const key = foodCategoryImageKey(code, file);
    const current = key ? await this.categories.find(code) : null;
    if (!key || !current || current.imageUrl !== foodCategoryImagePath(code, key)) {
      throw foodCategoryError(404, 'FOOD_CATEGORY_IMAGE_NOT_FOUND', 'Image not found');
    }
    const ext = file.slice(file.lastIndexOf('.') + 1);
    const contentType = ext === 'jpg' ? 'image/jpeg' : `image/${ext}`;
    const found = await this.uploads.readDisplayImage({ key, contentType }, width);
    if (!found) {
      throw foodCategoryError(404, 'FOOD_CATEGORY_IMAGE_NOT_FOUND', 'Image not found');
    }
    return found;
  }

  // ---- ops --------------------------------------------------------------

  async listOps(): Promise<{ items: OpsFoodCategoryView[] }> {
    const [rows, counts] = await Promise.all([this.categories.list(), this.categories.storeCounts()]);
    return { items: rows.map((row) => this.toOps(row, counts.get(row.code) ?? 0)) };
  }

  async create(input: CreateFoodCategoryDto, actorUserId: string): Promise<OpsFoodCategoryView> {
    const rows = await this.categories.list();
    const code = uniqueFoodCategoryCode(input.nameVi, new Set(rows.map((r) => r.code)));
    const fields: FoodCategoryFields = {
      nameVi: input.nameVi,
      nameEn: input.nameEn,
      icon: input.icon,
      tone: input.tone,
      imageUrl: null,
      sortOrder: rows.reduce((max, r) => Math.max(max, r.sortOrder), -10) + 10,
      active: input.active ?? true,
    };
    const created = await this.categories.create(code, fields, actorUserId, {
      action: 'FOOD_CATEGORY_CREATE',
      reason: `Tạo danh mục ${input.nameVi}`,
      metadata: { code, ...fields },
    });
    this.invalidate();
    return this.toOps(created, 0);
  }

  async update(code: string, input: PatchFoodCategoryDto, actorUserId: string): Promise<OpsFoodCategoryView> {
    const current = await this.require(code);
    const patch: Partial<FoodCategoryFields> = {
      nameVi: input.nameVi,
      nameEn: input.nameEn,
      icon: input.icon,
      tone: input.tone,
      active: input.active,
      imageUrl: input.imageUrl === null ? null : undefined,
    };
    const changes = diffCategory(current, patch);
    if (Object.keys(changes).length === 0) {
      return this.toOps(current, await this.storeCount(code));
    }
    const updated = await this.categories.update(code, patch, actorUserId, {
      action: 'FOOD_CATEGORY_UPDATE',
      reason: `Sửa danh mục ${current.nameVi}`,
      metadata: { changes },
    });
    if (!updated) throw NOT_FOUND();
    if (input.imageUrl === null) {
      const previous = keyFromFoodCategoryImageUrl(current.imageUrl);
      if (previous) await this.uploads.discard([{ key: previous }]);
    }
    this.invalidate();
    return this.toOps(updated, await this.storeCount(code));
  }

  async remove(code: string, actorUserId: string): Promise<{ code: string; deleted: true }> {
    const current = await this.require(code);
    const result = await this.categories.delete(code, actorUserId, {
      action: 'FOOD_CATEGORY_DELETE',
      reason: `Xoá danh mục ${current.nameVi}`,
      metadata: { code, nameVi: current.nameVi },
    });
    if (result === 'not_found') throw NOT_FOUND();
    if (result === 'in_use') {
      throw foodCategoryError(
        409,
        'FOOD_CATEGORY_IN_USE',
        'Stores still use this category; turn it off instead or move the stores first',
      );
    }
    const previous = keyFromFoodCategoryImageUrl(current.imageUrl);
    if (previous) await this.uploads.discard([{ key: previous }]);
    this.invalidate();
    return { code, deleted: true };
  }

  async reorder(codes: readonly string[], actorUserId: string): Promise<{ items: OpsFoodCategoryView[] }> {
    // Listed codes first (deduped, unknown dropped), the rest keep their order.
    const current = (await this.categories.list()).map((row) => row.code);
    const known = new Set(current);
    const listed = [...new Set(codes)].filter((code) => known.has(code));
    const ordered = [...listed, ...current.filter((code) => !listed.includes(code))];
    await this.categories.reorder(ordered, actorUserId, {
      action: 'FOOD_CATEGORY_REORDER',
      reason: 'Sắp xếp danh mục cửa hàng',
      metadata: { codes: ordered },
    });
    this.invalidate();
    return this.listOps();
  }

  async uploadImage(
    code: string,
    input: UploadFoodCategoryImageDto,
    actorUserId: string,
  ): Promise<OpsFoodCategoryView> {
    const current = await this.require(code);
    const payload = resolveFoodCategoryImagePayload(input);
    if (!payload) {
      throw foodCategoryError(400, 'VALIDATION_ERROR', 'contentBase64 or dataUrl is required');
    }
    const declared = payload.contentType?.toLowerCase();
    const normalized = declared === 'image/jpg' ? 'image/jpeg' : declared;
    if (normalized && !(FOOD_CATEGORY_IMAGE_TYPES as readonly string[]).includes(normalized)) {
      throw IMAGE_TYPE();
    }
    const previous = keyFromFoodCategoryImageUrl(current.imageUrl);
    const saved = await this.uploads.storePublicThen(
      `${FOOD_CATEGORY_STORAGE_PREFIX}/${code}`,
      [{ label: 'food-category', contentType: payload.contentType, contentBase64: payload.base64 }],
      async ([ref]) => {
        if (!ref || !(FOOD_CATEGORY_IMAGE_TYPES as readonly string[]).includes(ref.contentType)) {
          throw IMAGE_TYPE();
        }
        const imageUrl = foodCategoryImagePath(code, ref.key);
        const updated = await this.categories.update(code, { imageUrl }, actorUserId, {
          action: 'FOOD_CATEGORY_UPDATE',
          reason: `Cập nhật ảnh danh mục ${current.nameVi}`,
          metadata: { changes: { imageUrl: { from: current.imageUrl, to: imageUrl } } },
        });
        if (!updated) throw NOT_FOUND();
        return updated;
      },
    );
    if (previous) {
      await this.uploads.discard([{ key: previous }]);
    }
    this.invalidate();
    return this.toOps(saved, await this.storeCount(code));
  }

  // ---- helpers ----------------------------------------------------------

  private async require(code: string): Promise<FoodCategory> {
    const row = isFoodCategoryCode(code) ? await this.categories.find(code) : null;
    if (!row) throw NOT_FOUND();
    return row;
  }

  private async storeCount(code: string): Promise<number> {
    return (await this.categories.storeCounts()).get(code) ?? 0;
  }

  private async cachedActive(): Promise<FoodCategory[]> {
    const now = Date.now();
    if (!this.cache || now - this.cache.at > PUBLIC_CACHE_MS) {
      this.cache = { at: now, rows: (await this.categories.list()).filter((c) => c.active) };
    }
    return this.cache.rows;
  }

  private invalidate(): void {
    this.cache = null;
  }

  private toOps(row: FoodCategory, storeCount: number): OpsFoodCategoryView {
    return {
      ...toPublic(row),
      sortOrder: row.sortOrder,
      active: row.active,
      storeCount,
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
    };
  }
}

/** Fields that differ: `{ field: { from, to } }` for the ops audit log. */
export function diffCategory(
  current: FoodCategory,
  next: Partial<FoodCategoryFields>,
): Record<string, { from: unknown; to: unknown }> {
  const changes: Record<string, { from: unknown; to: unknown }> = {};
  for (const [field, to] of Object.entries(next)) {
    const from = current[field as keyof FoodCategory];
    if (to !== undefined && from !== to) {
      changes[field] = { from, to };
    }
  }
  return changes;
}
