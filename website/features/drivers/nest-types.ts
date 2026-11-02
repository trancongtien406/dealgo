import type { NestOpsUserGrant } from "@/features/customers/nest-types";
import type { OpsPerson } from "@/lib/api/ops-people";

/** Nest `OpsDriverListItem` = user directory + presence. */
export type NestOpsDriver = {
  id: string;
  displayName: string;
  phone: string | null;
  email: string | null;
  phoneVerifiedAt: string | null;
  emailVerifiedAt: string | null;
  createdAt: string;
  grants: NestOpsUserGrant[];
  /** S027 (DEC-PROD-037): null/absent = active account. */
  deletion?: unknown;
  presence: {
    online: boolean;
    lat: number | null;
    lng: number | null;
    updatedAt: string;
    /** Present when Nest exposes DriverPresence.serviceRegionCode. */
    serviceRegionCode?: string | null;
    /** Services the driver has switched on (Nest presence flags). */
    rideEnabled?: boolean;
    foodEnabled?: boolean;
    parcelEnabled?: boolean;
  } | null;
  /** BFF enrichment from `/v1/ops/people` (approved vehicle + rating). */
  profile?: OpsPerson | null;
  /** Driver KYC application details */
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
  /** Current active ride or food delivery in progress */
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
  /** 7-day performance breakdown */
  performance7d?: Array<{
    date: string;
    dayLabel: string;
    completedTrips: number;
    fareVnd: number;
    feeVnd: number;
    netVnd: number;
  }>;
  /** Driver stats summary */
  stats?: {
    completedRides: number;
    completedFoodOrders: number;
    finishedJobs: number;
    completionRate: number | null;
    ratingAverage: number | null;
    ratingCount: number;
  };
};

export type NestOpsDriverPage = {
  items: NestOpsDriver[];
  page: number;
  limit: number;
  total: number;
};
