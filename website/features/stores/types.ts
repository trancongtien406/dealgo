export const STORE_SALE_STATUSES = [
  "ACTIVE",
  "OPEN",
  "CLOSED",
  "PAUSED",
  "BUSY",
  "PENDING_APPROVAL",
  "SUSPENDED",
] as const;
export type StoreSaleStatus = (typeof STORE_SALE_STATUSES)[number];

export const STORE_KYB_STATUSES = [
  "APPROVED",
  "PENDING",
  "PENDING_KYB",
  "REJECTED",
  "NEEDS_VERIFY",
] as const;
export type StoreKybStatus = (typeof STORE_KYB_STATUSES)[number];

export type StoreListItem = {
  code: string;
  initials: string;
  name: string;
  category: string;
  owner: string;
  area: string;
  orders: number | null;
  rating: number | null;
  sale: StoreSaleStatus | null;
  kyb: StoreKybStatus | null;
  /** DEC-PROD-026: auto-resume time of a BUSY/PAUSED mode (ISO), when set. */
  serviceModeUntil: string | null;
  /** DEC-PROD-028: M022 intake line, e.g. "Tự động · tối đa 8 đơn"; null when not reported. */
  acceptSummary: string | null;
  /** Current kitchen estimate in minutes (default prep + BUSY extra). */
  prepMinutes: number | null;
};
