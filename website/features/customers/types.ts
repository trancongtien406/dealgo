import type { StatusTone } from "@/lib/admin-format";
import type { AccountDeletionInfo } from "@/lib/account-deletion";

export const CUSTOMER_STATUSES = [
  "ACTIVE",
  "NEEDS_SUPPORT",
  "SUSPENDED",
] as const;
export type CustomerStatus = (typeof CUSTOMER_STATUSES)[number];

export type CustomerListItem = {
  code: string;
  initials: string;
  name: string;
  phone: string;
  email?: string;
  area: string;
  rides: number;
  food: number;
  delivery: number;
  spend: number;
  status: CustomerStatus;
  time: string;
  createdAt?: string;
  phoneVerifiedAt?: string | null;
  lastLogin?: string;
  deletion?: AccountDeletionInfo | null;
};

export type CustomerActivityItem = {
  time: string;
  code: string;
  kind: string;
  summary: string;
  value: string;
  status: string;
  tone: StatusTone;
};

export type CustomerActivitiesPage = {
  items: CustomerActivityItem[];
  page: number;
  limit: number;
  total: number;
  tab: string;
};
