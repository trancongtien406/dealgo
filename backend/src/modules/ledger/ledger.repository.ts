import { randomUUID } from 'node:crypto';
import {
  LEDGER_CASH_IN_TRANSIT_CODE,
  LEDGER_COMMISSION_MERCHANT_RECEIVABLE_CODE,
  LEDGER_COMMISSION_REVENUE_CODE,
  LEDGER_PSP_CLEARING_CODE,
  LEDGER_PSP_CUSTOMER_PREPAID_CODE,
  LEDGER_PSP_PAYOUT_PAYABLE_CODE,
  LEDGER_PSP_REFUND_EXPENSE_CODE,
  LEDGER_COD_OBLIGATION_CODE,
  LEDGER_FEE_DRIVER_RECEIVABLE_CODE,
  LEDGER_FEE_REVENUE_CODE,
  LEDGER_PROMO_EXPENSE_CODE,
  LEDGER_PROMO_DRIVER_PAYABLE_CODE,
  LEDGER_PROMO_MERCHANT_PAYABLE_CODE,
  type LedgerEntityTypeName,
  type LedgerEntryDirectionName,
  type LedgerJournalEventName,
  type LedgerJournalStatusName,
} from './ledger.constants.js';
import {
  assertBalancedLines,
  buildCodObligationLines,
  buildDriverPlatformFeeLines,
  buildPromotionDiscountLines,
  LEDGER_LINE_BUILDERS,
  type PostableLedgerEvent,
  type LedgerLineBuilder,
} from './cod-journal.js';
import { LedgerRuleError } from './ledger.error.js';
import type { TxHandle } from '../../shared/tx/completion-hook.js';

export type LedgerEntryView = {
  id: string;
  accountCode: string;
  direction: LedgerEntryDirectionName;
  amountVnd: number;
};

export type LedgerJournalView = {
  id: string;
  entityType: LedgerEntityTypeName;
  entityId: string;
  event: LedgerJournalEventName;
  status: LedgerJournalStatusName;
  currency: 'VND';
  amountVnd: number;
  postedAt: string;
  entries: LedgerEntryView[];
};

export type PostCodObligationInput = {
  entityType: LedgerEntityTypeName;
  entityId: string;
  amountVnd: number;
};

type StoredAccount = {
  id: string;
  code: string;
  name: string;
  kind: 'ASSET' | 'LIABILITY' | 'EXPENSE' | 'REVENUE';
};

type StoredEntry = {
  id: string;
  journalId: string;
  accountId: string;
  direction: LedgerEntryDirectionName;
  amountVnd: number;
};

type StoredJournal = {
  id: string;
  entityType: LedgerEntityTypeName;
  entityId: string;
  event: LedgerJournalEventName;
  status: LedgerJournalStatusName;
  currency: 'VND';
  amountVnd: number;
  postedAt: Date;
};

export interface LedgerRepository {
  postCodObligation(input: PostCodObligationInput): Promise<LedgerJournalView>;
  /** Idempotent per entity: one funded-discount journal per order. */
  postPromotionDiscount(input: PostCodObligationInput): Promise<LedgerJournalView>;
  /** Idempotent per entity: one platform-fee journal per completed ride/order. */
  postDriverPlatformFee(input: PostCodObligationInput): Promise<LedgerJournalView>;
  /**
   * Posts inside the caller's transaction (Prisma `tx`, or null in memory mode) so the journal
   * commits or rolls back with the job's state change. Idempotent per entity + event.
   */
  postWithin(
    tx: TxHandle,
    event: PostableLedgerEvent,
    input: PostCodObligationInput,
  ): Promise<LedgerJournalView>;
  /** Standalone (own transaction) post; idempotent per entity + event. */
  postEvent(event: PostableLedgerEvent, input: PostCodObligationInput): Promise<LedgerJournalView>;
  findByEntity(
    entityType: LedgerEntityTypeName,
    entityId: string,
    event?: LedgerJournalEventName,
  ): Promise<LedgerJournalView | null>;
}

export class MemoryLedgerRepository implements LedgerRepository {
  private readonly accounts = new Map<string, StoredAccount>();
  private readonly journals = new Map<string, StoredJournal>();
  private readonly entries: StoredEntry[] = [];
  private tail: Promise<void> = Promise.resolve();

  constructor() {
    this.seedAccounts();
  }

  postCodObligation(input: PostCodObligationInput): Promise<LedgerJournalView> {
    return this.run(() =>
      this.postSync(input, 'COD_OBLIGATION_POSTED', buildCodObligationLines),
    );
  }

  postPromotionDiscount(input: PostCodObligationInput): Promise<LedgerJournalView> {
    return this.run(() =>
      this.postSync(input, 'PROMOTION_DISCOUNT_FUNDED', buildPromotionDiscountLines),
    );
  }

  postDriverPlatformFee(input: PostCodObligationInput): Promise<LedgerJournalView> {
    return this.run(() =>
      this.postSync(input, 'DRIVER_PLATFORM_FEE_ACCRUED', buildDriverPlatformFeeLines),
    );
  }

  postEvent(event: PostableLedgerEvent, input: PostCodObligationInput): Promise<LedgerJournalView> {
    return this.run(() => this.postSync(input, event, LEDGER_LINE_BUILDERS[event]));
  }

  /** Memory mode has no transaction; posting is synchronous so it cannot interleave. */
  async postWithin(
    _tx: TxHandle,
    event: PostableLedgerEvent,
    input: PostCodObligationInput,
  ): Promise<LedgerJournalView> {
    return this.postSync(input, event, LEDGER_LINE_BUILDERS[event]);
  }

  findByEntity(
    entityType: LedgerEntityTypeName,
    entityId: string,
    event: LedgerJournalEventName = 'COD_OBLIGATION_POSTED',
  ): Promise<LedgerJournalView | null> {
    return this.run(() => {
      const journal = [...this.journals.values()].find(
        (row) =>
          row.entityType === entityType && row.entityId === entityId && row.event === event,
      );
      return journal ? this.toView(journal) : null;
    });
  }

  private postSync(
    input: PostCodObligationInput,
    event: LedgerJournalEventName,
    buildLines: LedgerLineBuilder,
  ): LedgerJournalView {
    const existing = [...this.journals.values()].find(
      (row) =>
        row.entityType === input.entityType &&
        row.entityId === input.entityId &&
        row.event === event,
    );
    if (existing) {
      return this.toView(existing);
    }

    const lines = buildLines(input.amountVnd, input.entityType);
    assertBalancedLines(lines);

    const journal: StoredJournal = {
      id: randomUUID(),
      entityType: input.entityType,
      entityId: input.entityId,
      event,
      status: 'POSTED',
      currency: 'VND',
      amountVnd: input.amountVnd,
      postedAt: new Date(),
    };
    this.journals.set(journal.id, journal);

    for (const line of lines) {
      const account = this.requireAccount(line.accountCode);
      this.entries.push({
        id: randomUUID(),
        journalId: journal.id,
        accountId: account.id,
        direction: line.direction,
        amountVnd: line.amountVnd,
      });
    }

    return this.toView(journal);
  }

  private requireAccount(code: string): StoredAccount {
    const account = this.accounts.get(code);
    if (!account) {
      throw new LedgerRuleError('LEDGER_ACCOUNT_MISSING');
    }
    return account;
  }

  private toView(journal: StoredJournal): LedgerJournalView {
    const accountById = new Map([...this.accounts.values()].map((row) => [row.id, row]));
    const entries = this.entries
      .filter((entry) => entry.journalId === journal.id)
      .map((entry) => {
        const account = accountById.get(entry.accountId);
        if (!account) {
          throw new LedgerRuleError('LEDGER_ACCOUNT_MISSING');
        }
        return {
          id: entry.id,
          accountCode: account.code,
          direction: entry.direction,
          amountVnd: entry.amountVnd,
        };
      });
    return {
      id: journal.id,
      entityType: journal.entityType,
      entityId: journal.entityId,
      event: journal.event,
      status: journal.status,
      currency: journal.currency,
      amountVnd: journal.amountVnd,
      postedAt: journal.postedAt.toISOString(),
      entries,
    };
  }

  private seedAccounts(): void {
    const rows: StoredAccount[] = [
      {
        id: randomUUID(),
        code: LEDGER_CASH_IN_TRANSIT_CODE,
        name: 'Sandbox COD cash in transit (driver)',
        kind: 'ASSET',
      },
      {
        id: randomUUID(),
        code: LEDGER_COD_OBLIGATION_CODE,
        name: 'Sandbox COD platform clearing obligation',
        kind: 'LIABILITY',
      },
      {
        id: randomUUID(),
        code: LEDGER_PROMO_EXPENSE_CODE,
        name: 'Sandbox DealGo-funded voucher discount expense',
        kind: 'EXPENSE',
      },
      {
        id: randomUUID(),
        code: LEDGER_PROMO_MERCHANT_PAYABLE_CODE,
        name: 'Sandbox voucher discount owed to merchant',
        kind: 'LIABILITY',
      },
      {
        id: randomUUID(),
        code: LEDGER_PROMO_DRIVER_PAYABLE_CODE,
        name: 'Sandbox ride voucher discount owed to driver',
        kind: 'LIABILITY',
      },
      {
        id: randomUUID(),
        code: LEDGER_FEE_DRIVER_RECEIVABLE_CODE,
        name: 'Sandbox platform fee owed by driver (COD)',
        kind: 'ASSET',
      },
      {
        id: randomUUID(),
        code: LEDGER_FEE_REVENUE_CODE,
        name: 'Sandbox platform fee revenue',
        kind: 'REVENUE',
      },
      {
        id: randomUUID(),
        code: LEDGER_COMMISSION_MERCHANT_RECEIVABLE_CODE,
        name: 'Sandbox merchant commission receivable',
        kind: 'ASSET',
      },
      {
        id: randomUUID(),
        code: LEDGER_COMMISSION_REVENUE_CODE,
        name: 'Sandbox merchant commission revenue',
        kind: 'REVENUE',
      },
      {
        id: randomUUID(),
        code: LEDGER_PSP_CLEARING_CODE,
        name: 'Online payments held by PSP (clearing receivable)',
        kind: 'ASSET',
      },
      {
        id: randomUUID(),
        code: LEDGER_PSP_CUSTOMER_PREPAID_CODE,
        name: 'Customer prepayment for online-paid jobs',
        kind: 'LIABILITY',
      },
      {
        id: randomUUID(),
        code: LEDGER_PSP_PAYOUT_PAYABLE_CODE,
        name: 'Online-paid job payout owed to drivers',
        kind: 'LIABILITY',
      },
      {
        id: randomUUID(),
        code: LEDGER_PSP_REFUND_EXPENSE_CODE,
        name: 'Online refunds absorbed after settlement',
        kind: 'EXPENSE',
      },
    ];
    for (const row of rows) {
      this.accounts.set(row.code, row);
    }
  }

  private run<T>(work: () => T): Promise<T> {
    const execute = this.tail.then(() => work());
    this.tail = execute.then(
      () => undefined,
      () => undefined,
    );
    return execute;
  }
}
