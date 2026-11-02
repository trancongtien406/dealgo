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

/** A merchant edit (lower quantity / remove line) the customer answers. */
export type NestFoodOrderChange = {
  id: string;
  status: "PENDING" | "ACCEPTED" | "REJECTED" | "EXPIRED";
  reasonCode: string;
  note: string | null;
  lines: {
    lineId: string;
    name: string;
    unitPriceVnd: number;
    fromQuantity: number;
    toQuantity: number;
  }[];
  oldSubtotalVnd: number;
  newSubtotalVnd: number;
  newTotalVnd: number;
  expiresAt: string;
  respondedAt: string | null;
  createdAt: string;
};

export type NestFoodOrderView = {
  id: string;
  customerId: string;
  storeId: string;
  storeName?: string | null;
  serviceRegionCode?: string | null;
  status: NestFoodOrderStatus;
  deliveryFareVnd: number;
  /** Server suggestion at checkout; deliveryFareVnd is the customer offer / agreed fee. */
  suggestedDeliveryFareVnd?: number | null;
  deliveryFareAgreedAt?: string | null;
  deliveryFareRaiseCount?: number;
  /** Ops detail: current FOOD_DELIVERY_FEE_MODE. */
  deliveryFeeMode?: "NEGOTIATE" | "FIXED";
  deliveryOffers?: Array<{
    id: string;
    driverId: string;
    amountVnd: number;
    status: "PENDING" | "SELECTED" | "LOST" | "WITHDRAWN" | "EXPIRED";
    editCount: number;
    createdAt: string;
  }>;
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
  /** Ops detail only — latest merchant edit in any status. */
  latestChange?: NestFoodOrderChange | null;
  /** ISO placement time (older payloads omit it). */
  createdAt?: string | null;
};

export type NestFoodOrderPage = {
  items: NestFoodOrderView[];
  page: number;
  limit: number;
  total: number;
};
