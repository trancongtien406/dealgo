export type LedgerEntryDirection = "DEBIT" | "CREDIT";

export type LedgerEntryRow = {
  id: string;
  accountCode: string;
  direction: LedgerEntryDirection;
  amountVnd: number;
};

export type LedgerJournal = {
  id: string;
  entityType: "RIDE" | "FOOD_ORDER";
  entityId: string;
  event: string;
  status: string;
  currency: "VND";
  amountVnd: number;
  postedAt: string;
  postedAtLabel: string;
  entries: LedgerEntryRow[];
};
