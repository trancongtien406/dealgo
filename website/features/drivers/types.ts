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
  trips: number;
};
