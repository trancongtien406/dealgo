import type { NestOpsUserGrant } from "@/features/customers/nest-types";

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
  presence: {
    online: boolean;
    lat: number | null;
    lng: number | null;
    updatedAt: string;
    /** Present when Nest exposes DriverPresence.serviceRegionCode. */
    serviceRegionCode?: string | null;
  } | null;
};

export type NestOpsDriverPage = {
  items: NestOpsDriver[];
  page: number;
  limit: number;
  total: number;
};
