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
  } | null;
  /** BFF enrichment from `/v1/ops/people` (approved vehicle + rating). */
  profile?: OpsPerson | null;
};

export type NestOpsDriverPage = {
  items: NestOpsDriver[];
  page: number;
  limit: number;
  total: number;
};
