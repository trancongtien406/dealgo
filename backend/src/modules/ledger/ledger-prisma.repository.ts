import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import {
  LEDGER_CASH_IN_TRANSIT_CODE,
  LEDGER_COD_OBLIGATION_CODE,
  type LedgerEntityTypeName,
  type LedgerJournalEventName,
} from './ledger.constants.js';
import { assertBalancedLines, buildCodObligationLines } from './cod-journal.js';
import { LedgerRuleError } from './ledger.error.js';
import type {
  LedgerJournalView,
  LedgerRepository,
  PostCodObligationInput,
} from './ledger.repository.js';

const ACCOUNT_CODES = [LEDGER_CASH_IN_TRANSIT_CODE, LEDGER_COD_OBLIGATION_CODE] as const;

export class PrismaLedgerRepository implements LedgerRepository {
  constructor(private readonly db: PrismaClient) {}

  async postCodObligation(input: PostCodObligationInput): Promise<LedgerJournalView> {
    const lines = buildCodObligationLines(input.amountVnd);
    assertBalancedLines(lines);

    try {
      return await this.db.$transaction(async (tx) => {
        const existing = await tx.ledgerJournal.findUnique({
          where: {
            entityType_entityId_event: {
              entityType: input.entityType,
              entityId: input.entityId,
              event: 'COD_OBLIGATION_POSTED',
            },
          },
          include: {
            entries: { include: { account: true }, orderBy: { createdAt: 'asc' } },
          },
        });
        if (existing) {
          return toView(existing);
        }

        const accounts = await tx.ledgerAccount.findMany({
          where: { code: { in: [...ACCOUNT_CODES] } },
        });
        const byCode = new Map(accounts.map((row) => [row.code, row]));
        for (const code of ACCOUNT_CODES) {
          if (!byCode.has(code)) {
            throw new LedgerRuleError('LEDGER_ACCOUNT_MISSING');
          }
        }

        const created = await tx.ledgerJournal.create({
          data: {
            entityType: input.entityType,
            entityId: input.entityId,
            event: 'COD_OBLIGATION_POSTED',
            status: 'POSTED',
            currency: 'VND',
            amountVnd: input.amountVnd,
            entries: {
              create: lines.map((line) => ({
                accountId: byCode.get(line.accountCode)!.id,
                direction: line.direction,
                amountVnd: line.amountVnd,
              })),
            },
          },
          include: {
            entries: { include: { account: true }, orderBy: { createdAt: 'asc' } },
          },
        });
        return toView(created);
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const replay = await this.findByEntity(input.entityType, input.entityId);
        if (replay) {
          return replay;
        }
      }
      throw error;
    }
  }

  async findByEntity(
    entityType: LedgerEntityTypeName,
    entityId: string,
    event: LedgerJournalEventName = 'COD_OBLIGATION_POSTED',
  ): Promise<LedgerJournalView | null> {
    const journal = await this.db.ledgerJournal.findUnique({
      where: {
        entityType_entityId_event: {
          entityType,
          entityId,
          event,
        },
      },
      include: {
        entries: { include: { account: true }, orderBy: { createdAt: 'asc' } },
      },
    });
    return journal ? toView(journal) : null;
  }
}

type JournalRow = {
  id: string;
  entityType: LedgerEntityTypeName;
  entityId: string;
  event: LedgerJournalEventName;
  status: 'POSTED';
  currency: string;
  amountVnd: number;
  postedAt: Date;
  entries: {
    id: string;
    direction: 'DEBIT' | 'CREDIT';
    amountVnd: number;
    account: { code: string };
  }[];
};

function toView(journal: JournalRow): LedgerJournalView {
  return {
    id: journal.id,
    entityType: journal.entityType,
    entityId: journal.entityId,
    event: journal.event,
    status: journal.status,
    currency: 'VND',
    amountVnd: journal.amountVnd,
    postedAt: journal.postedAt.toISOString(),
    entries: journal.entries.map((entry) => ({
      id: entry.id,
      accountCode: entry.account.code,
      direction: entry.direction,
      amountVnd: entry.amountVnd,
    })),
  };
}
