export const LEDGER_JOURNAL_COLUMNS = [
  { id: "accountCode", label: "Tài khoản" },
  { id: "direction", label: "Hướng" },
  { id: "amountVnd", label: "Số tiền", align: "right" as const },
] as const;

export const LEDGER_JOURNAL_COLUMN_COUNT = LEDGER_JOURNAL_COLUMNS.length;
