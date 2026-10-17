export const SETTLEMENT_LINE_STATUSES = [
  "AWAITING_RECONCILE",
  "ELIGIBLE",
  "PROCESSING",
] as const;
export type SettlementLineStatus = (typeof SETTLEMENT_LINE_STATUSES)[number];

export type SettlementLine = {
  kind: string;
  ref: string;
  at: string;
  revenue: number;
  fee: number;
  provisional: number;
  status: SettlementLineStatus;
};
