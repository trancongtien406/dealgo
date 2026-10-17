export const TX_SERVICES = ["FOOD", "RIDE", "DELIVERY"] as const;
export type TxService = (typeof TX_SERVICES)[number];
export const TX_STATUSES = [
  "COLLECTED",
  "COD_PENDING",
  "COD_CONFIRMED",
  "PROCESSING",
  "FAILED",
] as const;
export type TxStatus = (typeof TX_STATUSES)[number];

export type TransactionListItem = {
  code: string;
  time: string;
  service: TxService;
  orderCode: string;
  customer: string;
  method: string;
  amount: number;
  status: TxStatus;
  area: string;
};
