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

export type NestRideStop = {
  seq: number;
  lat: number;
  lng: number;
  label: string;
  arrivedAt: string | null;
  departedAt: string | null;
};

export type NestRideView = {
  id: string;
  status: NestRideStatus;
  pickup: { lat: number; lng: number; label: string };
  dropoff: { lat: number; lng: number; label: string };
  /** Multi-stop: intermediate stops in visiting order (older payloads omit it). */
  stops?: NestRideStop[];
  routeVersion?: number;
  /** Per-stop fee in the reference and waiting fee billed at completion. */
  stopFeeVnd?: number;
  waitFeeVnd?: number;
  offeredFareVnd: number;
  referenceFareVnd: number;
  /** DG-DEC-VEH-001 catalog code (MOTORBIKE | CAR_4 | CAR_7, …). */
  vehicleClassCode?: string;
  agreedFareVnd: number | null;
  /** DEC-PROD-024: voucher reserved at selection; older payloads omit it. */
  discountVnd?: number;
  voucherCode?: string | null;
  cashDueVnd?: number | null;
  assignedDriverId: string | null;
  /** DEC-PROD-035: who cancelled (older payloads omit it). */
  cancelledBy?: NestCancelActor | null;
  /** Driver cancel reason / system timeout code, and customer no-show. */
  cancelReasonCode?: string | null;
  noShow?: boolean;
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
