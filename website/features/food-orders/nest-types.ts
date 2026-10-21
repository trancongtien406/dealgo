import type { NestCancelActor } from "@/lib/cancel-actor";
import type { OpsPerson } from "@/lib/api/ops-people";

/** Nest PublicFoodOrder subset used by Admin BFF (envelope.data). */
export type NestFoodOrderStatus =
  | "PLACED"
  | "PREPARING"
  | "READY"
  | "ASSIGNED"
  | "PICKED_UP"
  | "DELIVERED"
  | "FAILED"
  | "CANCELLED";

/** Option snapshot taken at placement (DEC-PROD-033); [] for plain dishes. */
export type NestFoodLineOption = {
  optionId?: string;
  groupName: string;
  name: string;
  priceDeltaVnd: number;
};

export type NestFoodLine = {
  itemId: string;
  name: string;
  /** Base price + option surcharges, per unit. */
  unitPriceVnd: number;
  quantity: number;
  options?: NestFoodLineOption[];
};

export type NestFoodOrderView = {
  id: string;
  customerId: string;
  storeId: string;
  storeName?: string | null;
  serviceRegionCode?: string | null;
  status: NestFoodOrderStatus;
  deliveryFareVnd: number;
  subtotalVnd: number;
  totalVnd: number;
  dropoff: { lat: number; lng: number; label: string };
  /** Store pickup point (null when the store has no location yet). */
  pickup?: { lat: number; lng: number; label: string | null } | null;
  assignedDriverId: string | null;
  /** BFF enrichment from `/v1/ops/people`. */
  customerProfile?: OpsPerson | null;
  driverProfile?: OpsPerson | null;
  lines: NestFoodLine[];
  /** Set when the store declined the order (DEC-PROD-021). */
  cancelReason?: { code: string; note: string | null } | null;
  /** DEC-PROD-035: who cancelled (older payloads omit it). */
  cancelledBy?: NestCancelActor | null;
};

export type NestFoodOrderPage = {
  items: NestFoodOrderView[];
  page: number;
  limit: number;
  total: number;
};
