import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client.js';
import type { PrismaClient } from '../../generated/prisma/client.js';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../shared/pagination/pagination.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import type { ExceptionReason } from './ops-exceptions.classify.js';
import {
  EXCEPTION_RECENT_MS,
  EXCEPTION_STUCK_AFTER_MS,
  FOOD_STUCK_STATUSES,
  FOOD_TERMINAL_STATUSES,
  RIDE_STUCK_STATUSES,
  RIDE_TERMINAL_STATUSES,
} from './ops-exceptions.constants.js';

export type OpsExceptionItem = {
  kind: 'ride' | 'food';
  id: string;
  status: string;
  reason: ExceptionReason;
  updatedAt: string;
  /** Pickup / dropoff short label for ops activity copy. */
  label: string | null;
};

type QueryClient = PrismaClient | Prisma.TransactionClient;

type RawExceptionRow = {
  kind: 'ride' | 'food';
  id: string;
  status: string;
  reason: string;
  updatedAt: Date;
  label: string | null;
};

/**
 * Cap per status arm. Single-status + ORDER BY updatedAt DESC LIMIT uses
 * (status, updatedAt) index and stops early — critical when seed marks most
 * rows "updated today" (recent window otherwise matches hundreds of thousands).
 */
const EXCEPTION_PER_STATUS_CAP = 50;

@Injectable()
export class OpsExceptionsService {
  private readonly logger = new Logger(OpsExceptionsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async list(
    page?: number,
    limit?: number,
    now = new Date(),
    filter?: { q?: string; status?: string },
  ): Promise<PageResult<OpsExceptionItem>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const stuckBefore = new Date(now.getTime() - EXCEPTION_STUCK_AFTER_MS);
    const recentAfter = new Date(now.getTime() - EXCEPTION_RECENT_MS);
    const perStatusCap = Math.min(
      EXCEPTION_PER_STATUS_CAP,
      Math.max(safeLimit * safePage, safeLimit),
    );

    const db = this.prisma.db();
    if (!db) {
      return { items: [], page: safePage, limit: safeLimit, total: 0 };
    }

    const statusFilter = filter?.status?.trim().toUpperCase();
    const q = filter?.q?.trim().toLowerCase() ?? '';

    try {
      const rows = await this.fetchExceptionCandidates(
        db,
        recentAfter,
        stuckBefore,
        perStatusCap,
      );

      let filtered: OpsExceptionItem[] = rows.map((row) => ({
        kind: row.kind,
        id: row.id,
        status: row.status,
        reason: row.reason as ExceptionReason,
        updatedAt: row.updatedAt.toISOString(),
        label: row.label?.trim() ? row.label.trim() : null,
      }));

      if (statusFilter && statusFilter !== 'ALL') {
        filtered = filtered.filter(
          (item) =>
            item.status.toUpperCase() === statusFilter ||
            item.reason.toUpperCase() === statusFilter,
        );
      }
      if (q) {
        filtered = filtered.filter(
          (item) =>
            item.id.toLowerCase().includes(q) ||
            item.kind.toLowerCase().includes(q) ||
            item.status.toLowerCase().includes(q) ||
            item.reason.toLowerCase().includes(q),
        );
      }

      const total = filtered.length;
      const start = (safePage - 1) * safeLimit;
      return {
        items: filtered.slice(start, start + safeLimit),
        page: safePage,
        limit: safeLimit,
        total,
      };
    } catch (error) {
      if (error instanceof Error) {
        this.logger.error(
          `ops.exceptions.list failed: ${error.message}`,
          error.stack,
        );
      } else {
        this.logger.error(`ops.exceptions.list failed: ${String(error)}`);
      }
      throw error;
    }
  }

  async countOpen(now = new Date(), client?: QueryClient): Promise<number> {
    const db = client ?? this.prisma.db();
    if (!db) {
      return 0;
    }

    const stuckBefore = new Date(now.getTime() - EXCEPTION_STUCK_AFTER_MS);
    const recentAfter = new Date(now.getTime() - EXCEPTION_RECENT_MS);

    try {
      const rows = await this.fetchExceptionCandidates(
        db,
        recentAfter,
        stuckBefore,
        EXCEPTION_PER_STATUS_CAP,
      );
      return rows.length;
    } catch (error) {
      if (error instanceof Error) {
        this.logger.error(
          `ops.exceptions.countOpen failed: ${error.message}`,
          error.stack,
        );
      } else {
        this.logger.error(`ops.exceptions.countOpen failed: ${String(error)}`);
      }
      return 0;
    }
  }

  /**
   * One indexed arm per status so LIMIT stops after N leaf rows.
   * Building SQL dynamically is safe: status literals come from constants, not user input.
   */
  private async fetchExceptionCandidates(
    db: QueryClient,
    recentAfter: Date,
    stuckBefore: Date,
    perStatusCap: number,
  ): Promise<RawExceptionRow[]> {
    const arms: string[] = [];

    for (const status of RIDE_TERMINAL_STATUSES) {
      arms.push(`
        (
          SELECT
            'ride'::text AS kind,
            id::text AS id,
            status::text AS status,
            'terminal'::text AS reason,
            "updatedAt",
            "pickupLabel" AS label
          FROM rides
          WHERE status = '${status}'::"RideStatus"
            AND "updatedAt" >= $1
          ORDER BY "updatedAt" DESC
          LIMIT ${perStatusCap}
        )
      `);
    }
    for (const status of RIDE_STUCK_STATUSES) {
      arms.push(`
        (
          SELECT
            'ride'::text AS kind,
            id::text AS id,
            status::text AS status,
            'stuck'::text AS reason,
            "updatedAt",
            "pickupLabel" AS label
          FROM rides
          WHERE status = '${status}'::"RideStatus"
            AND "updatedAt" <= $2
          ORDER BY "updatedAt" DESC
          LIMIT ${perStatusCap}
        )
      `);
    }
    for (const status of FOOD_TERMINAL_STATUSES) {
      arms.push(`
        (
          SELECT
            'food'::text AS kind,
            id::text AS id,
            status::text AS status,
            'terminal'::text AS reason,
            "updatedAt",
            "dropoffLabel" AS label
          FROM food_orders
          WHERE status = '${status}'::"FoodOrderStatus"
            AND "updatedAt" >= $1
          ORDER BY "updatedAt" DESC
          LIMIT ${perStatusCap}
        )
      `);
    }
    for (const status of FOOD_STUCK_STATUSES) {
      arms.push(`
        (
          SELECT
            'food'::text AS kind,
            id::text AS id,
            status::text AS status,
            'stuck'::text AS reason,
            "updatedAt",
            "dropoffLabel" AS label
          FROM food_orders
          WHERE status = '${status}'::"FoodOrderStatus"
            AND "updatedAt" <= $2
          ORDER BY "updatedAt" DESC
          LIMIT ${perStatusCap}
        )
      `);
    }

    const sql = `
      SELECT kind, id, status, reason, "updatedAt", label
      FROM (
        ${arms.join('\nUNION ALL\n')}
      ) candidates
      ORDER BY "updatedAt" DESC, id ASC
    `;

    return db.$queryRawUnsafe<RawExceptionRow[]>(sql, recentAfter, stuckBefore);
  }
}
