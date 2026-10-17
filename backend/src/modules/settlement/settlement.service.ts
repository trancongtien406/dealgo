import { Injectable } from '@nestjs/common';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../shared/pagination/pagination.js';
import { PrismaService } from '../../platform/database/prisma.service.js';

export type SettlementBatch = {
  /** UTC calendar day (YYYY-MM-DD). */
  day: string;
  journalCount: number;
  totalAmountVnd: number;
  entityTypes: Array<'RIDE' | 'FOOD_ORDER' | 'DISPUTE'>;
};

export type OpsSettlementBatch = SettlementBatch;

/**
 * Settlement service: groups COD ledger journals by UTC day.
 */
@Injectable()
export class SettlementService {
  constructor(private readonly prisma: PrismaService) {}

  async list(page?: number, limit?: number): Promise<PageResult<SettlementBatch>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const db = this.prisma.db();
    if (!db) {
      return { items: [], page: safePage, limit: safeLimit, total: 0 };
    }

    const journals = await db.ledgerJournal.findMany({
      where: { event: 'COD_OBLIGATION_POSTED', status: 'POSTED' },
      select: { entityType: true, amountVnd: true, postedAt: true },
      orderBy: { postedAt: 'desc' },
      take: 5_000,
    });

    const byDay = new Map<string, SettlementBatch>();
    for (const journal of journals) {
      const day = journal.postedAt.toISOString().slice(0, 10);
      const existing = byDay.get(day);
      if (!existing) {
        byDay.set(day, {
          day,
          journalCount: 1,
          totalAmountVnd: journal.amountVnd,
          entityTypes: [journal.entityType],
        });
        continue;
      }
      existing.journalCount += 1;
      existing.totalAmountVnd += journal.amountVnd;
      if (!existing.entityTypes.includes(journal.entityType)) {
        existing.entityTypes.push(journal.entityType);
      }
    }

    const batches = [...byDay.values()].sort((a, b) => b.day.localeCompare(a.day));
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
