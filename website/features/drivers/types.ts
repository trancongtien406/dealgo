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
  vehicleBrand?: string;
  vehicleModel?: string;
  plate: string;
  licenseClass?: string;
  licenseNumber?: string;
  kyc: DriverKycStatus;
  activity: DriverActivityStatus;
  rating: number | null;
  /** Lifetime completed rides + delivered food orders; null when the profile lookup failed. */
  trips: number | null;
  /** Jobs that reached a final state while assigned (completed + cancelled/failed). */
  finishedJobs: number | null;
  /** Completion rate 0..1; null when unknown or nothing finished yet. */
  completionRate: number | null;
  phone?: string;
  phoneMasked?: string;
  email?: string;
  createdAt?: string;
  deletion?: AccountDeletionInfo | null;
  presence?: {
    online: boolean;
    lat: number | null;
    lng: number | null;
    serviceRegionCode?: string | null;
    rideEnabled?: boolean;
    foodEnabled?: boolean;
    parcelEnabled?: boolean;
    updatedAt: string;
  } | null;
  kycDetail?: {
    applicationId: string;
    status: string;
    vehicleType?: string | null;
    vehiclePlate?: string | null;
    vehicleBrand?: string | null;
    vehicleModel?: string | null;
    vehicleClassCode?: string | null;
    licenseClass?: string | null;
    licenseNumber?: string | null;
    bankName?: string | null;
    bankAccountNumber?: string | null;
    bankAccountHolder?: string | null;
    documentsWaived?: boolean;
    documentCount: number;
    submittedAt?: string | null;
    reviewedAt?: string | null;
  } | null;
  activeJob?: {
    type: 'RIDE' | 'FOOD';
    id: string;
    code: string;
    status: string;
    statusLabel: string;
    customerName?: string;
    pickupLabel: string;
    dropoffLabel: string;
    fareVnd: number;
    createdAt: string;
  } | null;
  performance7d?: Array<{
    date: string;
    dayLabel: string;
    completedTrips: number;
    fareVnd: number;
    feeVnd: number;
    netVnd: number;
  }>;
};

export type DriverActivityItem = {
  time: string;
  code: string;
  kind: string;
  summary: string;
  value: string;
  status: string;
  tone: string;
};

export type DriverActivitiesPage = {
  items: DriverActivityItem[];
  page: number;
  limit: number;
  total: number;
  tab: string;
};
