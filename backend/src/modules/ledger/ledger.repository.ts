import { randomUUID } from 'node:crypto';
import {
  LEDGER_CASH_IN_TRANSIT_CODE,
  LEDGER_COD_OBLIGATION_CODE,
  type LedgerEntityTypeName,
  type LedgerEntryDirectionName,
  type LedgerJournalEventName,
  type LedgerJournalStatusName,
} from './ledger.constants.js';
import { assertBalancedLines, buildCodObligationLines } from './cod-journal.js';
import { LedgerRuleError } from './ledger.error.js';

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
  kind: 'ASSET' | 'LIABILITY';
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
    return this.run(() => this.postSync(input));
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

  private postSync(input: PostCodObligationInput): LedgerJournalView {
    const existing = [...this.journals.values()].find(
      (row) =>
        row.entityType === input.entityType &&
        row.entityId === input.entityId &&
        row.event === 'COD_OBLIGATION_POSTED',
    );
    if (existing) {
      return this.toView(existing);
    }

    const lines = buildCodObligationLines(input.amountVnd);
    assertBalancedLines(lines);

    const journal: StoredJournal = {
      id: randomUUID(),
      entityType: input.entityType,
      entityId: input.entityId,
      event: 'COD_OBLIGATION_POSTED',
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
