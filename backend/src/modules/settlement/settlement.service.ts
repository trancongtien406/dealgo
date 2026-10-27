import { dayKeyInWindow } from '../operations/ops-date-window.js';
import { Injectable } from '@nestjs/common';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../shared/pagination/pagination.js';
import { PrismaService } from '../../platform/database/prisma.service.js';

export type SettlementBatch = {
  /** Vietnam (Asia/Ho_Chi_Minh) calendar day (YYYY-MM-DD). */
  day: string;
  journalCount: number;
  totalAmountVnd: number;
  entityTypes: Array<'RIDE' | 'FOOD_ORDER' | 'DISPUTE'>;
};

export type OpsSettlementBatch = SettlementBatch;

/**
 * Groups posted COD ledger journals by Vietnam business day (Asia/Ho_Chi_Minh, UTC+7).
 */
@Injectable()
export class SettlementService {
  constructor(private readonly prisma: PrismaService) {}

  async list(
    page?: number,
    limit?: number,
    range: { from?: string | null; to?: string | null } = {},
  ): Promise<PageResult<SettlementBatch>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const db = this.prisma.db();
    if (!db) {
      return { items: [], page: safePage, limit: safeLimit, total: 0 };
    }

    // Batches are Vietnam business days (Asia/Ho_Chi_Minh), aggregated in SQL so older days are
    // never silently dropped by a row cap. postedAt is stored as UTC without a zone.
    const rows = await db.$queryRaw<
      Array<{ day: string; journalCount: number; totalAmountVnd: bigint | number; entityTypes: string[] }>
    >`
      SELECT
        to_char(("postedAt" AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD') AS day,
        COUNT(*)::int AS "journalCount",
        COALESCE(SUM("amountVnd"), 0)::bigint AS "totalAmountVnd",
        array_agg(DISTINCT "entityType"::text) AS "entityTypes"
      FROM ledger_journals
      WHERE event = 'COD_OBLIGATION_POSTED' AND status = 'POSTED'
      GROUP BY 1`;
    const byDay = new Map<string, SettlementBatch>(
      rows.map((row) => [
        row.day,
        {
          day: row.day,
          journalCount: Number(row.journalCount),
          totalAmountVnd: Number(row.totalAmountVnd),
          entityTypes: row.entityTypes as SettlementBatch['entityTypes'],
        },
      ]),
    );

    const batches = [...byDay.values()]
      .filter((batch) => dayKeyInWindow(batch.day, range))
      .sort((a, b) => b.day.localeCompare(a.day));
    const total = batches.length;
    const start = (safePage - 1) * safeLimit;
    return {
      items: batches.slice(start, start + safeLimit),
      page: safePage,
      limit: safeLimit,
      total,
    };
  }
}

export const OpsSettlementsService = SettlementService;
export type OpsSettlementsService = SettlementService;
