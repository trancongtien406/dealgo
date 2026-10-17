/** Nest LedgerJournalView subset used by Admin BFF (envelope.data). */

export type NestLedgerEntryDirection = "DEBIT" | "CREDIT";

export type NestLedgerEntry = {
  id: string;
  accountCode: string;
  direction: NestLedgerEntryDirection;
  amountVnd: number;
};

export type NestLedgerJournal = {
  id: string;
  entityType: "RIDE" | "FOOD_ORDER";
  entityId: string;
  event: string;
  status: string;
  currency: "VND";
  amountVnd: number;
  postedAt: string;
  entries: NestLedgerEntry[];
};
