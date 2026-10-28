import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';
import {
  compareFoodCategories,
  type FoodCategory,
  type FoodCategoryIcon,
  type FoodCategoryTone,
} from './food-category.js';

export type FoodCategoryAuditAction =
  | 'FOOD_CATEGORY_CREATE'
  | 'FOOD_CATEGORY_UPDATE'
  | 'FOOD_CATEGORY_DELETE'
  | 'FOOD_CATEGORY_REORDER';

export type FoodCategoryAudit = {
  action: FoodCategoryAuditAction;
  reason: string;
  metadata: Record<string, unknown>;
};

export type FoodCategoryFields = Pick<
  FoodCategory,
  'nameVi' | 'nameEn' | 'icon' | 'tone' | 'imageUrl' | 'sortOrder' | 'active'
>;

export type FoodCategoryDeleteResult = 'deleted' | 'not_found' | 'in_use';

export interface FoodCategoryRepository {
  list(): Promise<FoodCategory[]>;
  find(code: string): Promise<FoodCategory | null>;
  /** Stores per category code (categories without stores are absent). */
  storeCounts(): Promise<Map<string, number>>;
  create(
    code: string,
    fields: FoodCategoryFields,
    actorUserId: string,
    audit: FoodCategoryAudit,
  ): Promise<FoodCategory>;
  update(
    code: string,
    patch: Partial<FoodCategoryFields>,
    actorUserId: string,
    audit: FoodCategoryAudit,
  ): Promise<FoodCategory | null>;
  /** Refuses (`in_use`) while any store still points at the category. */
  delete(code: string, actorUserId: string, audit: FoodCategoryAudit): Promise<FoodCategoryDeleteResult>;
  /** Sets sortOrder = index * 10 for the given codes (unknown codes are ignored). */
  reorder(codes: readonly string[], actorUserId: string, audit: FoodCategoryAudit): Promise<FoodCategory[]>;
}

/** The defaults the migration seeds; memory mode starts from the same list. */
export const DEFAULT_FOOD_CATEGORIES: ReadonlyArray<
  Pick<FoodCategory, 'code' | 'nameVi' | 'nameEn' | 'icon' | 'tone'>
> = [
  { code: 'pho', nameVi: 'Phở', nameEn: 'Pho', icon: 'soup', tone: 'orange' },
  { code: 'noodles', nameVi: 'Bún, mì', nameEn: 'Noodles', icon: 'cooking-pot', tone: 'amber' },
  { code: 'rice', nameVi: 'Cơm', nameEn: 'Rice', icon: 'utensils', tone: 'red' },
  { code: 'banh_mi', nameVi: 'Bánh mì', nameEn: 'Banh mi', icon: 'sandwich', tone: 'brown' },
  { code: 'tea', nameVi: 'Trà sữa', nameEn: 'Milk tea', icon: 'cup-soda', tone: 'pink' },
  { code: 'cafe', nameVi: 'Cà phê', nameEn: 'Coffee', icon: 'coffee', tone: 'blue' },
  { code: 'fast_food', nameVi: 'Ăn nhanh', nameEn: 'Fast food', icon: 'hamburger', tone: 'green' },
  { code: 'snack', nameVi: 'Ăn vặt', nameEn: 'Snacks', icon: 'popcorn', tone: 'purple' },
  { code: 'mart', nameVi: 'Siêu thị', nameEn: 'Grocery', icon: 'shopping-cart', tone: 'indigo' },
];

export class MemoryFoodCategoryRepository implements FoodCategoryRepository {
  private readonly rows = new Map<string, FoodCategory>();
  /** Store counts are owned by the food module; specs set them directly. */
  readonly counts = new Map<string, number>();
  /** Audit entries (in-memory mode only). */
  readonly audits: Array<{ entityId: string; actorUserId: string } & FoodCategoryAudit> = [];

  constructor(seed: boolean = true) {
    if (seed) {
      const now = new Date();
      DEFAULT_FOOD_CATEGORIES.forEach((c, index) =>
        this.rows.set(c.code, {
          ...c,
          imageUrl: null,
          sortOrder: index * 10,
          active: true,
          createdAt: now,
          updatedAt: now,
        }),
      );
    }
  }

  async list(): Promise<FoodCategory[]> {
    return [...this.rows.values()].sort(compareFoodCategories).map((r) => ({ ...r }));
  }

  async find(code: string): Promise<FoodCategory | null> {
    const row = this.rows.get(code);
    return row ? { ...row } : null;
  }

  async storeCounts(): Promise<Map<string, number>> {
    return new Map(this.counts);
  }

  async create(
    code: string,
    fields: FoodCategoryFields,
    actorUserId: string,
    audit: FoodCategoryAudit,
  ): Promise<FoodCategory> {
    const now = new Date();
    const row: FoodCategory = { ...fields, code, createdAt: now, updatedAt: now };
    this.rows.set(code, row);
    this.audits.push({ entityId: code, actorUserId, ...audit });
    return { ...row };
  }

  async update(
    code: string,
    patch: Partial<FoodCategoryFields>,
    actorUserId: string,
    audit: FoodCategoryAudit,
  ): Promise<FoodCategory | null> {
    const row = this.rows.get(code);
    if (!row) {
      return null;
    }
    const next: FoodCategory = { ...row, ...defined(patch), updatedAt: new Date() };
    this.rows.set(code, next);
    this.audits.push({ entityId: code, actorUserId, ...audit });
    return { ...next };
  }

  async delete(code: string, actorUserId: string, audit: FoodCategoryAudit): Promise<FoodCategoryDeleteResult> {
    if (!this.rows.has(code)) {
      return 'not_found';
    }
    if ((this.counts.get(code) ?? 0) > 0) {
      return 'in_use';
    }
    this.rows.delete(code);
    this.audits.push({ entityId: code, actorUserId, ...audit });
    return 'deleted';
  }

  async reorder(codes: readonly string[], actorUserId: string, audit: FoodCategoryAudit): Promise<FoodCategory[]> {
    codes.forEach((code, index) => {
      const row = this.rows.get(code);
      if (row) {
        this.rows.set(code, { ...row, sortOrder: index * 10, updatedAt: new Date() });
      }
    });
    if (codes[0]) {
      this.audits.push({ entityId: codes[0], actorUserId, ...audit });
    }
    return this.list();
  }
}

function defined<T extends object>(patch: T): Partial<T> {
  return Object.fromEntries(Object.entries(patch).filter(([, v]) => v !== undefined)) as Partial<T>;
}

type FoodCategoryRecord = {
  code: string;
  nameVi: string;
  nameEn: string;
  icon: string;
  tone: string;
  imageUrl: string | null;
  sortOrder: number;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
};

function fromRecord(row: FoodCategoryRecord): FoodCategory {
  return {
    code: row.code,
    nameVi: row.nameVi,
    nameEn: row.nameEn,
    icon: row.icon as FoodCategoryIcon,
    tone: row.tone as FoodCategoryTone,
    imageUrl: row.imageUrl,
    sortOrder: row.sortOrder,
    active: row.active,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

type Tx = Parameters<Parameters<PrismaClient['$transaction']>[0]>[0];

async function writeAudit(tx: Tx, entityId: string, actorUserId: string, audit: FoodCategoryAudit) {
  await tx.opsAuditLog.create({
    data: {
      id: randomUUID(),
      actorUserId,
      action: audit.action,
      entityType: 'FOOD_CATEGORY',
      entityId,
      reason: audit.reason.slice(0, 500),
      metadata: audit.metadata as never,
    },
  });
}

export class PrismaFoodCategoryRepository implements FoodCategoryRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(): Promise<FoodCategory[]> {
    const rows = await this.db.foodCategory.findMany({ orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }] });
    return rows.map(fromRecord);
  }

  async find(code: string): Promise<FoodCategory | null> {
    const row = await this.db.foodCategory.findUnique({ where: { code } });
    return row ? fromRecord(row) : null;
  }

  async storeCounts(): Promise<Map<string, number>> {
    const groups = await this.db.foodStore.groupBy({
      by: ['category'],
      where: { category: { not: null } },
      _count: { _all: true },
    });
    return new Map(groups.map((g) => [g.category!, g._count._all]));
  }

  async create(
    code: string,
    fields: FoodCategoryFields,
    actorUserId: string,
    audit: FoodCategoryAudit,
  ): Promise<FoodCategory> {
    const row = await this.db.$transaction(async (tx) => {
      const created = await tx.foodCategory.create({ data: { ...fields, code } });
      await writeAudit(tx, code, actorUserId, audit);
      return created;
    });
    return fromRecord(row);
  }

  async update(
    code: string,
    patch: Partial<FoodCategoryFields>,
    actorUserId: string,
    audit: FoodCategoryAudit,
  ): Promise<FoodCategory | null> {
    const row = await this.db.$transaction(async (tx) => {
      const found = await tx.foodCategory.findUnique({ where: { code }, select: { code: true } });
      if (!found) {
        return null;
      }
      const updated = await tx.foodCategory.update({ where: { code }, data: patch });
      await writeAudit(tx, code, actorUserId, audit);
      return updated;
    });
    return row ? fromRecord(row) : null;
  }

  async delete(code: string, actorUserId: string, audit: FoodCategoryAudit): Promise<FoodCategoryDeleteResult> {
    return this.db.$transaction(async (tx) => {
      const found = await tx.foodCategory.findUnique({ where: { code }, select: { code: true } });
      if (!found) {
        return 'not_found';
      }
      if ((await tx.foodStore.count({ where: { category: code } })) > 0) {
        return 'in_use';
      }
      await tx.foodCategory.delete({ where: { code } });
      await writeAudit(tx, code, actorUserId, audit);
      return 'deleted';
    });
  }

  async reorder(codes: readonly string[], actorUserId: string, audit: FoodCategoryAudit): Promise<FoodCategory[]> {
    await this.db.$transaction(async (tx) => {
      for (const [index, code] of codes.entries()) {
        await tx.foodCategory.updateMany({ where: { code }, data: { sortOrder: index * 10 } });
      }
      if (codes[0]) {
        await writeAudit(tx, codes[0], actorUserId, audit);
      }
    });
    return this.list();
  }
}
