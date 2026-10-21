import type { NestCancelActor } from "@/lib/cancel-actor";
import type { OpsPerson } from "@/lib/api/ops-people";

/** Nest RideView subset used by Admin BFF (envelope.data). */
export type NestRideStatus =
  | "NEGOTIATING"
  | "ASSIGNED"
  | "DRIVER_EN_ROUTE"
  | "DRIVER_ARRIVED"
  | "IN_TRIP"
  | "COMPLETED"
  | "CANCELLED"
  | "EXPIRED";

export type NestRideOffer = {
  id: string;
  driverId: string;
  amountVnd: number;
  kind: string;
  status: string;
  expiresAt: string;
  /** BFF enrichment from `/v1/ops/people` (null when unknown). */
  driverProfile?: OpsPerson | null;
};

export type NestRideView = {
  id: string;
  status: NestRideStatus;
  pickup: { lat: number; lng: number; label: string };
  dropoff: { lat: number; lng: number; label: string };
  offeredFareVnd: number;
  referenceFareVnd: number;
  agreedFareVnd: number | null;
  /** DEC-PROD-024: voucher reserved at selection; older payloads omit it. */
  discountVnd?: number;
  voucherCode?: string | null;
  cashDueVnd?: number | null;
  assignedDriverId: string | null;
  /** DEC-PROD-035: who cancelled (older payloads omit it). */
  cancelledBy?: NestCancelActor | null;
  selectedOfferId: string | null;
  expiresAt: string;
  /** Present on Nest RideView; used when assignedDriverId is null. */
  offers?: NestRideOffer[];
  /** Ops-only: the booking customer (Nest OpsRideView). */
  customerId?: string;
  /** BFF enrichment from `/v1/ops/people`: real name + masked phone/plate. */
  customerProfile?: OpsPerson | null;
  driverProfile?: OpsPerson | null;
};

export type NestRidePage = {
  items: NestRideView[];
  page: number;
  limit: number;
  total: number;
};
