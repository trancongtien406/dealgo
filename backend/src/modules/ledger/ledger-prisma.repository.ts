import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import {
  type LedgerEntityTypeName,
  type LedgerJournalEventName,
} from './ledger.constants.js';
import {
  assertBalancedLines,
  buildCodObligationLines,
  buildDriverPlatformFeeLines,
  buildPromotionDiscountLines,
  type CodJournalLine,
  LEDGER_LINE_BUILDERS,
  type PostableLedgerEvent,
} from './cod-journal.js';
import type { TxHandle } from '../../shared/tx/completion-hook.js';
import { LedgerRuleError } from './ledger.error.js';
import type {
  LedgerJournalView,
  LedgerRepository,
  PostCodObligationInput,
} from './ledger.repository.js';

export class PrismaLedgerRepository implements LedgerRepository {
  constructor(private readonly db: PrismaClient) {}

  async postCodObligation(
    input: PostCodObligationInput,
  ): Promise<LedgerJournalView> {
    return this.post(
      input,
      'COD_OBLIGATION_POSTED',
      buildCodObligationLines(input.amountVnd),
    );
  }

  async postPromotionDiscount(
    input: PostCodObligationInput,
  ): Promise<LedgerJournalView> {
    return this.post(
      input,
      'PROMOTION_DISCOUNT_FUNDED',
      buildPromotionDiscountLines(input.amountVnd, input.entityType),
    );
  }

  async postDriverPlatformFee(
    input: PostCodObligationInput,
  ): Promise<LedgerJournalView> {
    return this.post(
      input,
      'DRIVER_PLATFORM_FEE_ACCRUED',
      buildDriverPlatformFeeLines(input.amountVnd),
    );
  }

  async postEvent(
    event: PostableLedgerEvent,
    input: PostCodObligationInput,
  ): Promise<LedgerJournalView> {
    return this.post(input, event, LEDGER_LINE_BUILDERS[event](input.amountVnd, input.entityType));
  }

  async postWithin(
    tx: TxHandle,
    event: PostableLedgerEvent,
    input: PostCodObligationInput,
  ): Promise<LedgerJournalView> {
    // The caller holds the job row lock, so no concurrent duplicate can race this insert.
    return postJournalInTx(
      tx as Prisma.TransactionClient,
      input,
      event,
      LEDGER_LINE_BUILDERS[event](input.amountVnd, input.entityType),
    );
  }

  private async post(
    input: PostCodObligationInput,
    event: LedgerJournalEventName,
    lines: CodJournalLine[],
  ): Promise<LedgerJournalView> {
    try {
      return await this.db.$transaction((tx) =>
        postJournalInTx(tx, input, event, lines),
      );
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const replay = await this.findByEntity(
          input.entityType,
          input.entityId,
          event,
        );
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

/** Finds or creates one balanced journal per entity + event inside `tx`. */
async function postJournalInTx(
  tx: Prisma.TransactionClient,
  input: PostCodObligationInput,
  event: LedgerJournalEventName,
  lines: CodJournalLine[],
): Promise<LedgerJournalView> {
  assertBalancedLines(lines);
  const accountCodes = [...new Set(lines.map((line) => line.accountCode))];
  const existing = await tx.ledgerJournal.findUnique({
    where: {
      entityType_entityId_event: {
        entityType: input.entityType,
        entityId: input.entityId,
        event,
      },
    },
    include: {
      entries: {
        include: { account: true },
        orderBy: { createdAt: 'asc' },
      },
    },
  });
  if (existing) {
    return toView(existing);
  }

  const accounts = await tx.ledgerAccount.findMany({
    where: { code: { in: accountCodes } },
  });
  const byCode = new Map(accounts.map((row) => [row.code, row]));
  for (const code of accountCodes) {
    if (!byCode.has(code)) {
      throw new LedgerRuleError('LEDGER_ACCOUNT_MISSING');
    }
  }

  const created = await tx.ledgerJournal.create({
    data: {
      entityType: input.entityType,
      entityId: input.entityId,
      event,
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
      entries: {
        include: { account: true },
        orderBy: { createdAt: 'asc' },
      },
    },
  });
  return toView(created);
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
