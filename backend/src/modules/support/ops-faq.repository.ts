import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';
import type { OpsFaqSeed } from './ops-faq.seed.js';

export type OpsFaqStatusName = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
export type OpsFaqCategoryName = 'POLICY' | 'OPS' | 'PRODUCT' | 'TECH';
export type FaqAudienceName = 'INTERNAL' | 'CUSTOMER' | 'DRIVER' | 'MERCHANT';

export type OpsFaqRecord = {
  id: string;
  openId: string | null;
  question: string;
  suggestedAnswer: string;
  status: OpsFaqStatusName;
  category: OpsFaqCategoryName;
  audience: FaqAudienceName;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
  createdByUserId: string | null;
  updatedByUserId: string | null;
};

export type CreateOpsFaqInput = {
  openId?: string | null;
  question: string;
  suggestedAnswer: string;
  status?: OpsFaqStatusName;
  category: OpsFaqCategoryName;
  audience?: FaqAudienceName;
  sortOrder?: number;
  actorUserId: string;
  reason: string;
};

export type PatchOpsFaqInput = {
  id: string;
  openId?: string | null;
  question?: string;
  suggestedAnswer?: string;
  status?: OpsFaqStatusName;
  category?: OpsFaqCategoryName;
  audience?: FaqAudienceName;
  sortOrder?: number;
  actorUserId: string;
  reason: string;
};

export interface OpsFaqRepository {
  list(status?: OpsFaqStatusName): Promise<OpsFaqRecord[]>;
  /** PUBLISHED entries for one in-app audience, in display order. */
  listPublished(audience: FaqAudienceName): Promise<OpsFaqRecord[]>;
  findById(id: string): Promise<OpsFaqRecord | null>;
  create(input: CreateOpsFaqInput): Promise<OpsFaqRecord>;
  patch(input: PatchOpsFaqInput): Promise<OpsFaqRecord | null>;
  ensureSeeds(seeds: readonly OpsFaqSeed[]): Promise<void>;
}

export class MemoryOpsFaqRepository implements OpsFaqRepository {
  private readonly byId = new Map<string, OpsFaqRecord>();
  readonly audits: Array<{
    action: 'FAQ_UPDATE';
    entityId: string;
    actorUserId: string;
    reason: string;
    metadata: Record<string, unknown>;
  }> = [];

  async list(status?: OpsFaqStatusName): Promise<OpsFaqRecord[]> {
    let rows = [...this.byId.values()];
    if (status) {
      rows = rows.filter((r) => r.status === status);
    }
    return rows.sort((a, b) => a.sortOrder - b.sortOrder || a.openId?.localeCompare(b.openId ?? '') || 0);
  }

  async listPublished(audience: FaqAudienceName): Promise<OpsFaqRecord[]> {
    return (await this.list('PUBLISHED')).filter((r) => r.audience === audience);
  }

  async findById(id: string): Promise<OpsFaqRecord | null> {
    return this.byId.get(id) ?? null;
  }

  async create(input: CreateOpsFaqInput): Promise<OpsFaqRecord> {
    const record: OpsFaqRecord = {
      id: randomUUID(),
      openId: input.openId ?? null,
      question: input.question,
      suggestedAnswer: input.suggestedAnswer,
      status: input.status ?? 'DRAFT',
      category: input.category,
      audience: input.audience ?? 'INTERNAL',
      sortOrder: input.sortOrder ?? 0,
      createdAt: new Date(),
      updatedAt: new Date(),
      createdByUserId: input.actorUserId,
      updatedByUserId: input.actorUserId,
    };
    this.byId.set(record.id, record);
    this.audits.push({
      action: 'FAQ_UPDATE',
      entityId: record.id,
      actorUserId: input.actorUserId,
      reason: input.reason,
      metadata: { op: 'create', openId: record.openId, status: record.status },
    });
    return record;
  }

  async patch(input: PatchOpsFaqInput): Promise<OpsFaqRecord | null> {
    const current = this.byId.get(input.id);
    if (!current) {
      return null;
    }
    const next: OpsFaqRecord = {
      ...current,
      openId: input.openId !== undefined ? input.openId : current.openId,
      question: input.question ?? current.question,
      suggestedAnswer: input.suggestedAnswer ?? current.suggestedAnswer,
      status: input.status ?? current.status,
      category: input.category ?? current.category,
      audience: input.audience ?? current.audience,
      sortOrder: input.sortOrder ?? current.sortOrder,
      updatedAt: new Date(),
      updatedByUserId: input.actorUserId,
    };
    this.byId.set(next.id, next);
    this.audits.push({
      action: 'FAQ_UPDATE',
      entityId: next.id,
      actorUserId: input.actorUserId,
      reason: input.reason,
      metadata: { op: 'patch', previousStatus: current.status, status: next.status },
    });
    return next;
  }

  async ensureSeeds(seeds: readonly OpsFaqSeed[]): Promise<void> {
    const existingOpenIds = new Set(
      [...this.byId.values()].map((r) => r.openId).filter((id): id is string => Boolean(id)),
    );
    for (const seed of seeds) {
      if (existingOpenIds.has(seed.openId)) {
        continue;
      }
      const id = randomUUID();
      this.byId.set(id, {
        id,
        openId: seed.openId,
        question: seed.question,
        suggestedAnswer: seed.suggestedAnswer,
        status: seed.status ?? 'DRAFT',
        category: seed.category,
        audience: seed.audience ?? 'INTERNAL',
        sortOrder: seed.sortOrder,
        createdAt: new Date(),
        updatedAt: new Date(),
        createdByUserId: null,
        updatedByUserId: null,
      });
      existingOpenIds.add(seed.openId);
    }
  }
}

export class PrismaOpsFaqRepository implements OpsFaqRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(status?: OpsFaqStatusName): Promise<OpsFaqRecord[]> {
    const rows = await this.db.opsFaqEntry.findMany({
      where: status ? { status } : undefined,
      orderBy: [{ sortOrder: 'asc' }, { openId: 'asc' }],
    });
    return rows.map(mapFaq);
  }

  async listPublished(audience: FaqAudienceName): Promise<OpsFaqRecord[]> {
    const rows = await this.db.opsFaqEntry.findMany({
      where: { status: 'PUBLISHED', audience },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      take: 100,
    });
    return rows.map(mapFaq);
  }

  async findById(id: string): Promise<OpsFaqRecord | null> {
    const row = await this.db.opsFaqEntry.findUnique({ where: { id } });
    return row ? mapFaq(row) : null;
  }

  async create(input: CreateOpsFaqInput): Promise<OpsFaqRecord> {
    return this.db.$transaction(async (tx) => {
      const created = await tx.opsFaqEntry.create({
        data: {
          id: randomUUID(),
          openId: input.openId ?? null,
          question: input.question,
          suggestedAnswer: input.suggestedAnswer,
          status: input.status ?? 'DRAFT',
          category: input.category,
          audience: input.audience ?? 'INTERNAL',
          sortOrder: input.sortOrder ?? 0,
          createdByUserId: input.actorUserId,
          updatedByUserId: input.actorUserId,
        },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'FAQ_UPDATE',
          entityType: 'OPS_FAQ',
          entityId: created.id,
          reason: input.reason,
          metadata: { op: 'create', openId: created.openId, status: created.status },
        },
      });
      return mapFaq(created);
    });
  }

  async patch(input: PatchOpsFaqInput): Promise<OpsFaqRecord | null> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.opsFaqEntry.findUnique({ where: { id: input.id } });
      if (!current) {
        return null;
      }
      const updated = await tx.opsFaqEntry.update({
        where: { id: input.id },
        data: {
          openId: input.openId !== undefined ? input.openId : undefined,
          question: input.question,
          suggestedAnswer: input.suggestedAnswer,
          status: input.status,
          category: input.category,
          audience: input.audience,
          sortOrder: input.sortOrder,
          updatedByUserId: input.actorUserId,
        },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'FAQ_UPDATE',
          entityType: 'OPS_FAQ',
          entityId: updated.id,
          reason: input.reason,
          metadata: {
            op: 'patch',
            previousStatus: current.status,
            status: updated.status,
          },
        },
      });
      return mapFaq(updated);
    });
  }

  async ensureSeeds(seeds: readonly OpsFaqSeed[]): Promise<void> {
    for (const seed of seeds) {
      const existing = await this.db.opsFaqEntry.findFirst({
        where: { openId: seed.openId },
        select: { id: true, suggestedAnswer: true },
      });
      if (existing) {
        if (existing.suggestedAnswer?.includes('PROPOSED (chưa duyệt)')) {
          await this.db.opsFaqEntry.update({
            where: { id: existing.id },
            data: {
              suggestedAnswer: seed.suggestedAnswer,
              question: seed.question,
              sortOrder: seed.sortOrder,
              category: seed.category,
            },
          });
        }
        continue;
      }
      await this.db.opsFaqEntry.create({
        data: {
          id: randomUUID(),
          openId: seed.openId,
          question: seed.question,
          suggestedAnswer: seed.suggestedAnswer,
          status: seed.status ?? 'DRAFT',
          category: seed.category,
          audience: seed.audience ?? 'INTERNAL',
          sortOrder: seed.sortOrder,
        },
      });
    }
  }
}

function mapFaq(row: {
  id: string;
  openId: string | null;
  question: string;
  suggestedAnswer: string;
  status: string;
  category: string;
  audience: string;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
  createdByUserId: string | null;
  updatedByUserId: string | null;
}): OpsFaqRecord {
  return {
    id: row.id,
    openId: row.openId,
    question: row.question,
    suggestedAnswer: row.suggestedAnswer,
    status: row.status as OpsFaqStatusName,
    category: row.category as OpsFaqCategoryName,
    audience: row.audience as FaqAudienceName,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    createdByUserId: row.createdByUserId,
    updatedByUserId: row.updatedByUserId,
  };
}
