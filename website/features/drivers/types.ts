import type { AccountDeletionInfo } from "@/lib/account-deletion";
export const DRIVER_KYC_STATUSES = [
  "VERIFIED",
  "NEEDS_MORE_INFO",
  "UNDER_REVIEW",
  "NEEDS_REVERIFY",
] as const;
export type DriverKycStatus = (typeof DRIVER_KYC_STATUSES)[number];

export const DRIVER_ACTIVITY_STATUSES = [
  "ON_TRIP",
  "DELIVERING",
  "ONLINE",
  "PAUSED",
  "OFFLINE",
  "SUSPENDED",
] as const;
export type DriverActivityStatus = (typeof DRIVER_ACTIVITY_STATUSES)[number];

export type DriverListItem = {
  code: string;
  initials: string;
  name: string;
  area: string;
  service: string;
  vehicle: string;
  vehicleKind: string;
  plate: string;
  kyc: DriverKycStatus;
  activity: DriverActivityStatus;
  rating: number | null;
  /** Lifetime completed rides + delivered food orders; null when the profile lookup failed. */
  trips: number | null;
  /** Jobs that reached a final state while assigned (completed + cancelled/failed). */
  finishedJobs: number | null;
  /** Completion rate 0..1; null when unknown or nothing finished yet. */
  completionRate: number | null;
  deletion?: AccountDeletionInfo | null;
};
