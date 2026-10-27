import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { normalizeLimit, normalizePage, type PageResult } from '../../shared/pagination/pagination.js';
import { PrismaService } from '../database/prisma.service.js';

export type AuditLogItem = {
  id: string;
  code: string;
  time: string;
  createdAt: string;
  actor: string;
  actorId: string;
  action: string;
  target: string;
  entityType: string;
  entityId: string;
  reason: string;
  result: 'SUCCESS' | 'PENDING_APPROVAL' | 'LOGGED' | 'REJECTED';
  metadata?: Record<string, unknown>;
};

export type OpsAuditLogItem = AuditLogItem;

/** Audit times are shown in Vietnam time (UTC+7, no DST). */
const VN_OFFSET_MS = 7 * 3600_000;

@Injectable()
export class AuditLogsService {
  /**
   * Entries recorded through `record()`. Only listed when no database is configured
   * (memory mode / unit tests); with a database the list comes from `ops_audit_logs`,
   * which the domain services write inside their own transactions.
   */
  private readonly logger = new Logger(AuditLogsService.name);

  private readonly inMemoryLogs: AuditLogItem[] = [];

  constructor(private readonly prisma: PrismaService) {}

  record(log: Omit<AuditLogItem, 'id' | 'code' | 'time' | 'createdAt'>): AuditLogItem {
    const nextSeq = this.inMemoryLogs.length + 1;
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    const timeFormatted = `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()} ${pad(now.getHours())}:${pad(now.getMinutes())}`;

    const item: AuditLogItem = {
      ...log,
      id: `aud-${nextSeq}`,
      code: `AUD-${String(nextSeq).padStart(5, '0')}`,
      time: timeFormatted,
      createdAt: now.toISOString(),
    };

    this.inMemoryLogs.unshift(item);
    return item;
  }

  async list(options: {
    q?: string;
    entityType?: string;
    result?: string;
    page?: number;
    limit?: number;
  }): Promise<PageResult<AuditLogItem>> {
    const safePage = normalizePage(options.page);
    const safeLimit = normalizeLimit(options.limit);

    let allItems = [...this.inMemoryLogs];

    const db = this.prisma.db();
    if (db) {
      allItems = [];
      try {
        const prismaLogs = await db.opsAuditLog.findMany({
          include: { actor: true },
          orderBy: { createdAt: 'desc' },
          take: 200,
        });

        for (const p of prismaLogs) {
          const createdAt = p.createdAt.toISOString();
          const d = p.createdAt;
          const pad = (n: number) => String(n).padStart(2, '0');
          const local = new Date(d.getTime() + VN_OFFSET_MS);
          const time = `${pad(local.getUTCDate())}/${pad(local.getUTCMonth() + 1)}/${local.getUTCFullYear()} ${pad(local.getUTCHours())}:${pad(local.getUTCMinutes())}`;
          const metadata = (p.metadata as Record<string, unknown> | null) ?? {};
          const code = `AUD-DB-${p.id.slice(0, 6).toUpperCase()}`;

          {
            allItems.push({
              id: p.id,
              code,
              time,
              createdAt,
              actor: p.actor.email ?? p.actor.phone ?? 'Operator',
              actorId: p.actorUserId,
              action: p.action,
              target:
                typeof metadata.code === 'string'
                  ? `${p.entityType}:${metadata.code}`
                  : `${p.entityType}:${p.entityId.slice(0, 8)}`,
              entityType: p.entityType,
              entityId: p.entityId,
              reason: p.reason,
              result: 'SUCCESS',
              metadata,
            });
          }
        }

        // Sort all items descending by createdAt
        allItems.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
      } catch (error) {
        this.logger.error(`ops audit log read failed: ${(error as Error).message}`);
        throw new InternalServerErrorException({
          message: 'Audit log is temporarily unavailable',
          errorCode: 'AUDIT_LOG_UNAVAILABLE',
        });
      }
    }

    // Apply filtering
    if (options.q && options.q.trim()) {
      const q = options.q.trim().toLowerCase();
      allItems = allItems.filter(
        (i) =>
          i.code.toLowerCase().includes(q) ||
          i.actor.toLowerCase().includes(q) ||
          i.action.toLowerCase().includes(q) ||
          i.target.toLowerCase().includes(q) ||
          i.reason.toLowerCase().includes(q),
      );
    }

    if (options.entityType && options.entityType !== 'ALL') {
      const et = options.entityType.toUpperCase();
      allItems = allItems.filter((i) => i.entityType.toUpperCase() === et);
    }

    if (options.result && options.result !== 'ALL') {
      const r = options.result.toUpperCase();
      allItems = allItems.filter((i) => i.result === r);
    }

    const total = allItems.length;
    const start = (safePage - 1) * safeLimit;
    const items = allItems.slice(start, start + safeLimit);

    return {
      items,
      page: safePage,
      limit: safeLimit,
      total,
    };
  }
}

export { AuditLogsService as OpsAuditLogsService };
