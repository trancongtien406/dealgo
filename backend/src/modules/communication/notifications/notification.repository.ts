import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../../generated/prisma/client.js';
import { writeCampaignSendOutbox } from '../outbox/outbox.write.js';
import type { CampaignSeed, CmsSeed } from './notification.seed.js';

export type NotificationChannelName = 'PUSH' | 'SMS' | 'EMAIL' | 'IN_APP';
export type NotificationAudienceName = 'ALL' | 'CUSTOMER' | 'DRIVER' | 'MERCHANT' | 'STAFF';
export type CampaignStatusName =
  | 'DRAFT'
  | 'PENDING_APPROVAL'
  | 'RUNNING'
  | 'SENDING'
  | 'SENT'
  | 'CANCELLED';
export type CampaignTabName = 'ALL' | 'RUNNING' | 'SENT' | 'PENDING' | 'DRAFT';
export type CmsKindName = 'ARTICLE' | 'BANNER' | 'POLICY';
export type CmsStatusName = 'DRAFT' | 'IN_REVIEW' | 'PUBLISHED';

export type CampaignRecord = {
  id: string;
  code: string;
  title: string;
  body: string;
  channels: NotificationChannelName[];
  audience: NotificationAudienceName;
  audienceNote: string | null;
  status: CampaignStatusName;
  isAutomatic: boolean;
  scheduledAt: Date | null;
  reachedCount: number | null;
  rejectionReason: string | null;
  submittedAt: Date | null;
  approvedAt: Date | null;
  sentAt: Date | null;
  cancelledAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  createdByUserId: string | null;
  updatedByUserId: string | null;
  approvedByUserId: string | null;
};

export type CampaignCounts = Record<'all' | 'running' | 'sent' | 'pending' | 'draft', number>;

export type CampaignListFilter = {
  page: number;
  limit: number;
  q?: string;
  tab: CampaignTabName;
  channel?: NotificationChannelName;
  audience?: NotificationAudienceName;
};

export type CampaignListResult = {
  rows: CampaignRecord[];
  total: number;
  counts: CampaignCounts;
};

export type CreateCampaignInput = {
  title: string;
  body: string;
  channels: NotificationChannelName[];
  audience: NotificationAudienceName;
  audienceNote?: string | null;
  isAutomatic: boolean;
  scheduledAt?: Date | null;
  actorUserId: string;
  reason: string;
};

/** Fields an admin can change while the campaign is a DRAFT. */
export type CampaignEditableData = Partial<
  Pick<
    CampaignRecord,
    'title' | 'body' | 'channels' | 'audience' | 'audienceNote' | 'isAutomatic' | 'scheduledAt'
  >
>;

/** System-managed lifecycle data written by transitions. */
export type CampaignTransitionData = CampaignEditableData &
  Partial<
    Pick<
      CampaignRecord,
      | 'status'
      | 'reachedCount'
      | 'rejectionReason'
      | 'submittedAt'
      | 'approvedAt'
      | 'sentAt'
      | 'cancelledAt'
      | 'approvedByUserId'
    >
  >;

export type ApplyCampaignInput = {
  code: string;
  /** Optimistic guard: the update only applies while the current status is in this list. */
  from: readonly CampaignStatusName[];
  data: CampaignTransitionData;
  actorUserId: string | null;
  op: string;
  reason: string;
};

export type ApplyCampaignResult =
  | { kind: 'OK'; record: CampaignRecord }
  | { kind: 'NOT_FOUND' }
  | { kind: 'CONFLICT'; current: CampaignStatusName };

export type CmsRecord = {
  id: string;
  kind: CmsKindName;
  title: string;
  body: string;
  status: CmsStatusName;
  publishedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  createdByUserId: string | null;
  updatedByUserId: string | null;
};

export type CmsListFilter = { kind?: CmsKindName; status?: CmsStatusName; q?: string };

export type CreateCmsInput = {
  kind: CmsKindName;
  title: string;
  body: string;
  status?: CmsStatusName;
  actorUserId: string;
  reason: string;
};

export type PatchCmsInput = {
  id: string;
  title?: string;
  body?: string;
  kind?: CmsKindName;
  status?: CmsStatusName;
  actorUserId: string;
  reason: string;
};

export interface OpsNotificationRepository {
  listCampaigns(filter: CampaignListFilter): Promise<CampaignListResult>;
  findCampaign(code: string): Promise<CampaignRecord | null>;
  createCampaign(input: CreateCampaignInput): Promise<CampaignRecord>;
  applyCampaign(input: ApplyCampaignInput): Promise<ApplyCampaignResult>;
  listCms(filter: CmsListFilter): Promise<CmsRecord[]>;
  findCms(id: string): Promise<CmsRecord | null>;
  createCms(input: CreateCmsInput): Promise<CmsRecord>;
  patchCms(input: PatchCmsInput): Promise<CmsRecord | null>;
  ensureSeeds(campaigns: readonly CampaignSeed[], cms: readonly CmsSeed[]): Promise<void>;
}

const RUNNING_STATUSES: readonly CampaignStatusName[] = ['RUNNING', 'SENDING'];

export function tabStatuses(tab: CampaignTabName): readonly CampaignStatusName[] | null {
  switch (tab) {
    case 'RUNNING':
      return RUNNING_STATUSES;
    case 'SENT':
      return ['SENT'];
    case 'PENDING':
      return ['PENDING_APPROVAL'];
    case 'DRAFT':
      return ['DRAFT'];
    default:
      return null;
  }
}

/** TB-YYMMDD-NNN in the Asia/Ho_Chi_Minh calendar day (UTC+7). */
export function campaignCodePrefix(now: Date): string {
  const vn = new Date(now.getTime() + 7 * 60 * 60 * 1000);
  const yy = String(vn.getUTCFullYear()).slice(2);
  const mm = String(vn.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(vn.getUTCDate()).padStart(2, '0');
  return `TB-${yy}${mm}${dd}-`;
}

export function nextCampaignCode(prefix: string, existingCodes: readonly string[]): string {
  let max = 0;
  for (const code of existingCodes) {
    if (!code.startsWith(prefix)) continue;
    const n = Number(code.slice(prefix.length));
    if (Number.isSafeInteger(n) && n > max) max = n;
  }
  return `${prefix}${String(max + 1).padStart(3, '0')}`;
}

function matchesQuery(c: CampaignRecord, q: string): boolean {
  return (
    c.title.toLowerCase().includes(q) ||
    c.code.toLowerCase().includes(q) ||
    c.body.toLowerCase().includes(q)
  );
}

function computeCounts(rows: readonly CampaignRecord[]): CampaignCounts {
  const by = (statuses: readonly CampaignStatusName[]) =>
    rows.filter((r) => statuses.includes(r.status)).length;
  return {
    all: rows.length,
    running: by(RUNNING_STATUSES),
    sent: by(['SENT']),
    pending: by(['PENDING_APPROVAL']),
    draft: by(['DRAFT']),
  };
}

export class MemoryOpsNotificationRepository implements OpsNotificationRepository {
  private readonly campaigns = new Map<string, CampaignRecord>();
  private readonly cms = new Map<string, CmsRecord>();
  readonly audits: Array<{
    action: 'NOTIFICATION_UPDATE' | 'CMS_UPDATE';
    entityId: string;
    actorUserId: string | null;
    reason: string;
    metadata: Record<string, unknown>;
  }> = [];

  async listCampaigns(filter: CampaignListFilter): Promise<CampaignListResult> {
    const q = filter.q?.trim().toLowerCase();
    // Counts ignore the tab (but honour the other filters) so tab badges stay stable.
    const base = [...this.campaigns.values()]
      .filter((c) => (q ? matchesQuery(c, q) : true))
      .filter((c) => (filter.channel ? c.channels.includes(filter.channel) : true))
      .filter((c) => (filter.audience ? c.audience === filter.audience : true))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime() || b.code.localeCompare(a.code));
    const statuses = tabStatuses(filter.tab);
    const filtered = statuses ? base.filter((c) => statuses.includes(c.status)) : base;
    const start = (filter.page - 1) * filter.limit;
    return {
      rows: filtered.slice(start, start + filter.limit),
      total: filtered.length,
      counts: computeCounts(base),
    };
  }

  async findCampaign(code: string): Promise<CampaignRecord | null> {
    return this.campaigns.get(code) ?? null;
  }

  async createCampaign(input: CreateCampaignInput): Promise<CampaignRecord> {
    const now = new Date();
    const code = nextCampaignCode(campaignCodePrefix(now), [...this.campaigns.keys()]);
    const record: CampaignRecord = {
      id: randomUUID(),
      code,
      title: input.title,
      body: input.body,
      channels: input.channels,
      audience: input.audience,
      audienceNote: input.audienceNote ?? null,
      status: 'DRAFT',
      isAutomatic: input.isAutomatic,
      scheduledAt: input.scheduledAt ?? null,
      reachedCount: null,
      rejectionReason: null,
      submittedAt: null,
      approvedAt: null,
      sentAt: null,
      cancelledAt: null,
      createdAt: now,
      updatedAt: now,
      createdByUserId: input.actorUserId,
      updatedByUserId: input.actorUserId,
      approvedByUserId: null,
    };
    this.campaigns.set(code, record);
    this.audits.push({
      action: 'NOTIFICATION_UPDATE',
      entityId: record.id,
      actorUserId: input.actorUserId,
      reason: input.reason,
      metadata: { op: 'create', code },
    });
    return record;
  }

  async applyCampaign(input: ApplyCampaignInput): Promise<ApplyCampaignResult> {
    const current = this.campaigns.get(input.code);
    if (!current) return { kind: 'NOT_FOUND' };
    if (!input.from.includes(current.status)) {
      return { kind: 'CONFLICT', current: current.status };
    }
    // Undefined means "leave unchanged" (same as Prisma); null is an explicit clear.
    const defined = Object.fromEntries(
      Object.entries(input.data).filter(([, value]) => value !== undefined),
    ) as CampaignTransitionData;
    const next: CampaignRecord = {
      ...current,
      ...defined,
      updatedAt: new Date(),
      updatedByUserId: input.actorUserId ?? current.updatedByUserId,
    };
    this.campaigns.set(next.code, next);
    this.audits.push({
      action: 'NOTIFICATION_UPDATE',
      entityId: next.id,
      actorUserId: input.actorUserId,
      reason: input.reason,
      metadata: { op: input.op, code: next.code, from: current.status, to: next.status },
    });
    return { kind: 'OK', record: next };
  }

  async listCms(filter: CmsListFilter): Promise<CmsRecord[]> {
    const q = filter.q?.trim().toLowerCase();
    return [...this.cms.values()]
      .filter((c) => (filter.kind ? c.kind === filter.kind : true))
      .filter((c) => (filter.status ? c.status === filter.status : true))
      .filter((c) => (q ? c.title.toLowerCase().includes(q) : true))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async findCms(id: string): Promise<CmsRecord | null> {
    return this.cms.get(id) ?? null;
  }

  async createCms(input: CreateCmsInput): Promise<CmsRecord> {
    const now = new Date();
    const status = input.status ?? 'DRAFT';
    const record: CmsRecord = {
      id: randomUUID(),
      kind: input.kind,
      title: input.title,
      body: input.body,
      status,
      publishedAt: status === 'PUBLISHED' ? now : null,
      createdAt: now,
      updatedAt: now,
      createdByUserId: input.actorUserId,
      updatedByUserId: input.actorUserId,
    };
    this.cms.set(record.id, record);
    this.audits.push({
      action: 'CMS_UPDATE',
      entityId: record.id,
      actorUserId: input.actorUserId,
      reason: input.reason,
      metadata: { op: 'create', kind: record.kind, status },
    });
    return record;
  }

  async patchCms(input: PatchCmsInput): Promise<CmsRecord | null> {
    const current = this.cms.get(input.id);
    if (!current) return null;
    const status = input.status ?? current.status;
    const next: CmsRecord = {
      ...current,
      title: input.title ?? current.title,
      body: input.body ?? current.body,
      kind: input.kind ?? current.kind,
      status,
      publishedAt:
        status === 'PUBLISHED' ? (current.publishedAt ?? new Date()) : current.publishedAt,
      updatedAt: new Date(),
      updatedByUserId: input.actorUserId,
    };
    this.cms.set(next.id, next);
    this.audits.push({
      action: 'CMS_UPDATE',
      entityId: next.id,
      actorUserId: input.actorUserId,
      reason: input.reason,
      metadata: { op: 'patch', previousStatus: current.status, status: next.status },
    });
    return next;
  }

  async ensureSeeds(campaigns: readonly CampaignSeed[], cms: readonly CmsSeed[]): Promise<void> {
    for (const s of campaigns) {
      if (this.campaigns.has(s.code)) continue;
      const created = new Date(s.createdAt);
      this.campaigns.set(s.code, {
        id: randomUUID(),
        code: s.code,
        title: s.title,
        body: s.body,
        channels: [...s.channels],
        audience: s.audience,
        audienceNote: s.audienceNote ?? null,
        status: s.status,
        isAutomatic: s.isAutomatic ?? false,
        scheduledAt: s.scheduledAt ? new Date(s.scheduledAt) : null,
        reachedCount: s.reachedCount ?? null,
        rejectionReason: null,
        submittedAt: null,
        approvedAt: null,
        sentAt: s.status === 'SENT' ? created : null,
        cancelledAt: null,
        createdAt: created,
        updatedAt: created,
        createdByUserId: null,
        updatedByUserId: null,
        approvedByUserId: null,
      });
    }
    const titles = new Set([...this.cms.values()].map((c) => c.title));
    for (const s of cms) {
      if (titles.has(s.title)) continue;
      const created = new Date(s.createdAt);
      const id = randomUUID();
      this.cms.set(id, {
        id,
        kind: s.kind,
        title: s.title,
        body: s.body,
        status: s.status,
        publishedAt: s.status === 'PUBLISHED' ? created : null,
        createdAt: created,
        updatedAt: created,
        createdByUserId: null,
        updatedByUserId: null,
      });
    }
  }
}

type CampaignRow = Omit<CampaignRecord, 'channels' | 'audience' | 'status'> & {
  channels: string[];
  audience: string;
  status: string;
};

function mapCampaign(row: CampaignRow): CampaignRecord {
  return {
    ...row,
    channels: row.channels as NotificationChannelName[],
    audience: row.audience as NotificationAudienceName,
    status: row.status as CampaignStatusName,
  };
}

type CmsRow = Omit<CmsRecord, 'kind' | 'status'> & { kind: string; status: string };

function mapCms(row: CmsRow): CmsRecord {
  return {
    ...row,
    kind: row.kind as CmsKindName,
    status: row.status as CmsStatusName,
  };
}

export class PrismaOpsNotificationRepository implements OpsNotificationRepository {
  constructor(private readonly db: PrismaClient) {}

  async listCampaigns(filter: CampaignListFilter): Promise<CampaignListResult> {
    const q = filter.q?.trim();
    const base = {
      ...(q
        ? {
            OR: [
              { title: { contains: q, mode: 'insensitive' as const } },
              { code: { contains: q, mode: 'insensitive' as const } },
              { body: { contains: q, mode: 'insensitive' as const } },
            ],
          }
        : {}),
      ...(filter.channel ? { channels: { has: filter.channel } } : {}),
      ...(filter.audience ? { audience: filter.audience } : {}),
    };
    const statuses = tabStatuses(filter.tab);
    const where = statuses ? { ...base, status: { in: [...statuses] } } : base;

    const [rows, total, grouped] = await Promise.all([
      this.db.notificationCampaign.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { code: 'desc' }],
        skip: (filter.page - 1) * filter.limit,
        take: filter.limit,
      }),
      this.db.notificationCampaign.count({ where }),
      this.db.notificationCampaign.groupBy({
        by: ['status'],
        where: base,
        _count: { _all: true },
      }),
    ]);

    const n = (statusList: readonly CampaignStatusName[]) =>
      grouped
        .filter((g) => statusList.includes(g.status as CampaignStatusName))
        .reduce((sum, g) => sum + g._count._all, 0);
    const counts: CampaignCounts = {
      all: grouped.reduce((sum, g) => sum + g._count._all, 0),
      running: n(RUNNING_STATUSES),
      sent: n(['SENT']),
      pending: n(['PENDING_APPROVAL']),
      draft: n(['DRAFT']),
    };
    return { rows: rows.map(mapCampaign), total, counts };
  }

  async findCampaign(code: string): Promise<CampaignRecord | null> {
    const row = await this.db.notificationCampaign.findUnique({ where: { code } });
    return row ? mapCampaign(row) : null;
  }

  async createCampaign(input: CreateCampaignInput): Promise<CampaignRecord> {
    const prefix = campaignCodePrefix(new Date());
    // Code is unique; retry on the (rare) race where two admins create at once.
    for (let attempt = 0; attempt < 5; attempt += 1) {
      try {
        return await this.db.$transaction(async (tx) => {
          const existing = await tx.notificationCampaign.findMany({
            where: { code: { startsWith: prefix } },
            select: { code: true },
          });
          const code = nextCampaignCode(
            prefix,
            existing.map((e) => e.code),
          );
          const created = await tx.notificationCampaign.create({
            data: {
              id: randomUUID(),
              code,
              title: input.title,
              body: input.body,
              channels: input.channels,
              audience: input.audience,
              audienceNote: input.audienceNote ?? null,
              isAutomatic: input.isAutomatic,
              scheduledAt: input.scheduledAt ?? null,
              createdByUserId: input.actorUserId,
              updatedByUserId: input.actorUserId,
            },
          });
          await tx.opsAuditLog.create({
            data: {
              id: randomUUID(),
              actorUserId: input.actorUserId,
              action: 'NOTIFICATION_UPDATE',
              entityType: 'NOTIFICATION_CAMPAIGN',
              entityId: created.id,
              reason: input.reason,
              metadata: { op: 'create', code },
            },
          });
          return mapCampaign(created);
        });
      } catch (error) {
        if (attempt < 4 && isUniqueViolation(error)) continue;
        throw error;
      }
    }
    throw new Error('Could not allocate a campaign code');
  }

  async applyCampaign(input: ApplyCampaignInput): Promise<ApplyCampaignResult> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.notificationCampaign.findUnique({ where: { code: input.code } });
      if (!current) return { kind: 'NOT_FOUND' } as const;
      // Compare-and-set on status so concurrent approvals cannot both win.
      const { count } = await tx.notificationCampaign.updateMany({
        where: { code: input.code, status: { in: [...input.from] } },
        data: {
          ...input.data,
          updatedByUserId: input.actorUserId ?? undefined,
        },
      });
      if (count === 0) {
        const latest = await tx.notificationCampaign.findUnique({ where: { code: input.code } });
        return {
          kind: 'CONFLICT',
          current: (latest?.status ?? current.status) as CampaignStatusName,
        } as const;
      }
      const updated = await tx.notificationCampaign.findUniqueOrThrow({
        where: { code: input.code },
      });
      if (input.actorUserId) {
        await tx.opsAuditLog.create({
          data: {
            id: randomUUID(),
            actorUserId: input.actorUserId,
            action: 'NOTIFICATION_UPDATE',
            entityType: 'NOTIFICATION_CAMPAIGN',
            entityId: updated.id,
            reason: input.reason,
            metadata: {
              op: input.op,
              code: updated.code,
              from: current.status,
              to: updated.status,
            },
          },
        });
      }
      if (
        updated.status === 'SENDING' &&
        updated.channels.includes('PUSH') &&
        input.op === 'approve'
      ) {
        await writeCampaignSendOutbox(tx, {
          campaignId: updated.id,
          code: updated.code,
          title: updated.title,
          body: updated.body,
          audience: updated.audience,
          channels: updated.channels,
        });
      }
      return { kind: 'OK', record: mapCampaign(updated) } as const;
    });
  }

  async listCms(filter: CmsListFilter): Promise<CmsRecord[]> {
    const q = filter.q?.trim();
    const rows = await this.db.cmsContent.findMany({
      where: {
        ...(filter.kind ? { kind: filter.kind } : {}),
        ...(filter.status ? { status: filter.status } : {}),
        ...(q ? { title: { contains: q, mode: 'insensitive' as const } } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map(mapCms);
  }

  async findCms(id: string): Promise<CmsRecord | null> {
    const row = await this.db.cmsContent.findUnique({ where: { id } });
    return row ? mapCms(row) : null;
  }

  async createCms(input: CreateCmsInput): Promise<CmsRecord> {
    return this.db.$transaction(async (tx) => {
      const status = input.status ?? 'DRAFT';
      const created = await tx.cmsContent.create({
        data: {
          id: randomUUID(),
          kind: input.kind,
          title: input.title,
          body: input.body,
          status,
          publishedAt: status === 'PUBLISHED' ? new Date() : null,
          createdByUserId: input.actorUserId,
          updatedByUserId: input.actorUserId,
        },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'CMS_UPDATE',
          entityType: 'CMS_CONTENT',
          entityId: created.id,
          reason: input.reason,
          metadata: { op: 'create', kind: created.kind, status },
        },
      });
      return mapCms(created);
    });
  }

  async patchCms(input: PatchCmsInput): Promise<CmsRecord | null> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.cmsContent.findUnique({ where: { id: input.id } });
      if (!current) return null;
      const status = input.status ?? (current.status as CmsStatusName);
      const updated = await tx.cmsContent.update({
        where: { id: input.id },
        data: {
          title: input.title,
          body: input.body,
          kind: input.kind,
          status,
          publishedAt:
            status === 'PUBLISHED' && !current.publishedAt ? new Date() : undefined,
          updatedByUserId: input.actorUserId,
        },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'CMS_UPDATE',
          entityType: 'CMS_CONTENT',
          entityId: updated.id,
          reason: input.reason,
          metadata: { op: 'patch', previousStatus: current.status, status: updated.status },
        },
      });
      return mapCms(updated);
    });
  }

  async ensureSeeds(campaigns: readonly CampaignSeed[], cms: readonly CmsSeed[]): Promise<void> {
    for (const s of campaigns) {
      const created = new Date(s.createdAt);
      await this.db.notificationCampaign.upsert({
        where: { code: s.code },
        update: {},
        create: {
          id: randomUUID(),
          code: s.code,
          title: s.title,
          body: s.body,
          channels: [...s.channels],
          audience: s.audience,
          audienceNote: s.audienceNote ?? null,
          status: s.status,
          isAutomatic: s.isAutomatic ?? false,
          scheduledAt: s.scheduledAt ? new Date(s.scheduledAt) : null,
          reachedCount: s.reachedCount ?? null,
          sentAt: s.status === 'SENT' ? created : null,
          createdAt: created,
        },
      });
    }
    for (const s of cms) {
      const existing = await this.db.cmsContent.findFirst({
        where: { title: s.title },
        select: { id: true },
      });
      if (existing) continue;
      const created = new Date(s.createdAt);
      await this.db.cmsContent.create({
        data: {
          id: randomUUID(),
          kind: s.kind,
          title: s.title,
          body: s.body,
          status: s.status,
          publishedAt: s.status === 'PUBLISHED' ? created : null,
          createdAt: created,
        },
      });
    }
  }
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2002'
  );
}

export type NotificationRepository = OpsNotificationRepository;
export const PrismaNotificationRepository = PrismaOpsNotificationRepository;
export type PrismaNotificationRepository = PrismaOpsNotificationRepository;
export const MemoryNotificationRepository = MemoryOpsNotificationRepository;
export type MemoryNotificationRepository = MemoryOpsNotificationRepository;

