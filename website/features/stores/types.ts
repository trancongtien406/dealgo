export const STORE_SALE_STATUSES = [
  "ACTIVE",
  "OPEN",
  "CLOSED",
  "PAUSED",
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
};
