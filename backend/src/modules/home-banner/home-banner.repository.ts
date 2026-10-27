import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';
import { compareHomeBanners, type HomeBanner } from './home-banner.js';

export type HomeBannerAuditAction =
  | 'HOME_BANNER_CREATE'
  | 'HOME_BANNER_UPDATE'
  | 'HOME_BANNER_DELETE'
  | 'HOME_BANNER_REORDER';

export type HomeBannerAudit = {
  action: HomeBannerAuditAction;
  reason: string;
  metadata: Record<string, unknown>;
};

export type HomeBannerFields = Pick<
  HomeBanner,
  | 'imageUrl'
  | 'ctaUrl'
  | 'audiences'
  | 'service'
  | 'regionCode'
  | 'startsAt'
  | 'endsAt'
  | 'sortOrder'
  | 'active'
>;

export type HomeBannerCounts = { impressions: number; clicks: number };

export interface HomeBannerRepository {
  list(): Promise<HomeBanner[]>;
  find(id: string): Promise<HomeBanner | null>;
  create(fields: HomeBannerFields, actorUserId: string, audit: HomeBannerAudit): Promise<HomeBanner>;
  update(
    id: string,
    patch: Partial<HomeBannerFields>,
    actorUserId: string,
    audit: HomeBannerAudit,
  ): Promise<HomeBanner | null>;
  delete(id: string, actorUserId: string, audit: HomeBannerAudit): Promise<HomeBanner | null>;
  /** Sets sortOrder = index * 10 for the given ids (unknown ids are ignored). */
  reorder(ids: readonly string[], actorUserId: string, audit: HomeBannerAudit): Promise<HomeBanner[]>;
  addStats(day: string, counts: ReadonlyMap<string, HomeBannerCounts>): Promise<void>;
  /** Totals per banner: all time and since `sinceDay` (inclusive, YYYY-MM-DD). */
  totals(sinceDay: string): Promise<Map<string, HomeBannerCounts & { recent: HomeBannerCounts }>>;
}

function clone(row: HomeBanner): HomeBanner {
  return { ...row, audiences: [...row.audiences] };
}

export class MemoryHomeBannerRepository implements HomeBannerRepository {
  private readonly rows = new Map<string, HomeBanner>();
  private readonly stats = new Map<string, HomeBannerCounts>();
  /** Audit entries (in-memory mode only). */
  readonly audits: Array<{ entityId: string; actorUserId: string } & HomeBannerAudit> = [];

  async list(): Promise<HomeBanner[]> {
    return [...this.rows.values()].sort(compareHomeBanners).map(clone);
  }

  async find(id: string): Promise<HomeBanner | null> {
    const row = this.rows.get(id);
    return row ? clone(row) : null;
  }

  async create(fields: HomeBannerFields, actorUserId: string, audit: HomeBannerAudit): Promise<HomeBanner> {
    const now = new Date();
    const row: HomeBanner = {
      ...fields,
      audiences: [...fields.audiences],
      id: randomUUID(),
      createdByUserId: actorUserId,
      updatedByUserId: actorUserId,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(row.id, row);
    this.audits.push({ entityId: row.id, actorUserId, ...audit });
    return clone(row);
  }

  async update(
    id: string,
    patch: Partial<HomeBannerFields>,
    actorUserId: string,
    audit: HomeBannerAudit,
  ): Promise<HomeBanner | null> {
    const row = this.rows.get(id);
    if (!row) {
      return null;
    }
    const next: HomeBanner = { ...row, ...patch, updatedByUserId: actorUserId, updatedAt: new Date() };
    this.rows.set(id, next);
    this.audits.push({ entityId: id, actorUserId, ...audit });
    return clone(next);
  }

  async delete(id: string, actorUserId: string, audit: HomeBannerAudit): Promise<HomeBanner | null> {
    const row = this.rows.get(id);
    if (!row) {
      return null;
    }
    this.rows.delete(id);
    for (const key of this.stats.keys()) {
      if (key.startsWith(`${id}|`)) {
        this.stats.delete(key);
      }
    }
    this.audits.push({ entityId: id, actorUserId, ...audit });
    return clone(row);
  }

  async reorder(ids: readonly string[], actorUserId: string, audit: HomeBannerAudit): Promise<HomeBanner[]> {
    ids.forEach((id, index) => {
      const row = this.rows.get(id);
      if (row) {
        this.rows.set(id, { ...row, sortOrder: index * 10, updatedByUserId: actorUserId, updatedAt: new Date() });
      }
    });
    this.audits.push({ entityId: ids[0] ?? '', actorUserId, ...audit });
    return this.list();
  }

  async addStats(day: string, counts: ReadonlyMap<string, HomeBannerCounts>): Promise<void> {
    for (const [id, c] of counts) {
      if (!this.rows.has(id)) {
        continue;
      }
      const key = `${id}|${day}`;
      const cur = this.stats.get(key) ?? { impressions: 0, clicks: 0 };
      this.stats.set(key, { impressions: cur.impressions + c.impressions, clicks: cur.clicks + c.clicks });
    }
  }

  async totals(sinceDay: string): Promise<Map<string, HomeBannerCounts & { recent: HomeBannerCounts }>> {
    const out = new Map<string, HomeBannerCounts & { recent: HomeBannerCounts }>();
    for (const [key, c] of this.stats) {
      const [id, day] = key.split('|') as [string, string];
      const cur = out.get(id) ?? { impressions: 0, clicks: 0, recent: { impressions: 0, clicks: 0 } };
      cur.impressions += c.impressions;
      cur.clicks += c.clicks;
      if (day >= sinceDay) {
        cur.recent.impressions += c.impressions;
        cur.recent.clicks += c.clicks;
      }
      out.set(id, cur);
    }
    return out;
  }
}

type Row = Awaited<ReturnType<PrismaClient['homeBanner']['findFirstOrThrow']>>;

function fromRecord(row: Row): HomeBanner {
  return {
    id: row.id,
    imageUrl: row.imageUrl,
    ctaUrl: row.ctaUrl,
    audiences: [...row.audiences],
    service: row.service,
    regionCode: row.regionCode,
    startsAt: row.startsAt,
    endsAt: row.endsAt,
    sortOrder: row.sortOrder,
    active: row.active,
    createdByUserId: row.createdByUserId,
    updatedByUserId: row.updatedByUserId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

type Tx = Parameters<Parameters<PrismaClient['$transaction']>[0]>[0];

async function writeAudit(tx: Tx, entityId: string, actorUserId: string, audit: HomeBannerAudit) {
  await tx.opsAuditLog.create({
    data: {
      id: randomUUID(),
      actorUserId,
      action: audit.action,
      entityType: 'HOME_BANNER',
      entityId,
      reason: audit.reason.slice(0, 500),
      metadata: audit.metadata as never,
    },
  });
}

export class PrismaHomeBannerRepository implements HomeBannerRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(): Promise<HomeBanner[]> {
    const rows = await this.db.homeBanner.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    });
    return rows.map(fromRecord);
  }

  async find(id: string): Promise<HomeBanner | null> {
    const row = await this.db.homeBanner.findUnique({ where: { id } });
    return row ? fromRecord(row) : null;
  }

  async create(fields: HomeBannerFields, actorUserId: string, audit: HomeBannerAudit): Promise<HomeBanner> {
    const row = await this.db.$transaction(async (tx) => {
      const created = await tx.homeBanner.create({
        data: { ...fields, id: randomUUID(), createdByUserId: actorUserId, updatedByUserId: actorUserId },
      });
      await writeAudit(tx, created.id, actorUserId, audit);
      return created;
    });
    return fromRecord(row);
  }

  async update(
    id: string,
    patch: Partial<HomeBannerFields>,
    actorUserId: string,
    audit: HomeBannerAudit,
  ): Promise<HomeBanner | null> {
    const row = await this.db.$transaction(async (tx) => {
      const found = await tx.homeBanner.findUnique({ where: { id }, select: { id: true } });
      if (!found) {
        return null;
      }
      const updated = await tx.homeBanner.update({
        where: { id },
        data: { ...patch, updatedByUserId: actorUserId },
      });
      await writeAudit(tx, id, actorUserId, audit);
      return updated;
    });
    return row ? fromRecord(row) : null;
  }

  async delete(id: string, actorUserId: string, audit: HomeBannerAudit): Promise<HomeBanner | null> {
    const row = await this.db.$transaction(async (tx) => {
      const found = await tx.homeBanner.findUnique({ where: { id } });
      if (!found) {
        return null;
      }
      await tx.homeBanner.delete({ where: { id } });
      await writeAudit(tx, id, actorUserId, audit);
      return found;
    });
    return row ? fromRecord(row) : null;
  }

  async reorder(ids: readonly string[], actorUserId: string, audit: HomeBannerAudit): Promise<HomeBanner[]> {
    await this.db.$transaction(async (tx) => {
      for (const [index, id] of ids.entries()) {
        await tx.homeBanner.updateMany({
          where: { id },
          data: { sortOrder: index * 10, updatedByUserId: actorUserId },
        });
      }
      if (ids[0]) {
        await writeAudit(tx, ids[0], actorUserId, audit);
      }
    });
    return this.list();
  }

  async addStats(day: string, counts: ReadonlyMap<string, HomeBannerCounts>): Promise<void> {
    const date = new Date(`${day}T00:00:00.000Z`);
    const ids = [...counts.keys()];
    if (ids.length === 0) {
      return;
    }
    const known = new Set(
      (await this.db.homeBanner.findMany({ where: { id: { in: ids } }, select: { id: true } })).map((r) => r.id),
    );
    for (const [bannerId, c] of counts) {
      if (!known.has(bannerId)) {
        continue;
      }
      await this.db.homeBannerDailyStat.upsert({
        where: { bannerId_day: { bannerId, day: date } },
        create: { bannerId, day: date, impressions: c.impressions, clicks: c.clicks },
        update: { impressions: { increment: c.impressions }, clicks: { increment: c.clicks } },
      });
    }
  }

  async totals(sinceDay: string): Promise<Map<string, HomeBannerCounts & { recent: HomeBannerCounts }>> {
    const since = new Date(`${sinceDay}T00:00:00.000Z`);
    const [all, recent] = await Promise.all([
      this.db.homeBannerDailyStat.groupBy({ by: ['bannerId'], _sum: { impressions: true, clicks: true } }),
      this.db.homeBannerDailyStat.groupBy({
        by: ['bannerId'],
        where: { day: { gte: since } },
        _sum: { impressions: true, clicks: true },
      }),
    ]);
    const out = new Map<string, HomeBannerCounts & { recent: HomeBannerCounts }>();
    for (const row of all) {
      out.set(row.bannerId, {
        impressions: row._sum.impressions ?? 0,
        clicks: row._sum.clicks ?? 0,
        recent: { impressions: 0, clicks: 0 },
      });
    }
    for (const row of recent) {
      const cur = out.get(row.bannerId);
      if (cur) {
        cur.recent = { impressions: row._sum.impressions ?? 0, clicks: row._sum.clicks ?? 0 };
      }
    }
    return out;
  }
}
