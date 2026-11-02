export const FOOD_ORDER_STATUSES = [
  "AWAITING_CONFIRMATION",
  "PREPARING",
  "DELIVERING",
  "COMPLETED",
  "CANCELLED",
] as const;

export type FoodOrderStatus = (typeof FOOD_ORDER_STATUSES)[number];

export type FoodOrderLine = {
  name: string;
  quantity: number;
  unitPriceVnd: number;
  /** e.g. "Size: L · Topping: Trân châu (+8.000đ)"; "" when none. */
  options: string;
};

/** Merchant edit summary for the ops detail. */
export type FoodOrderChangeSummary = {
  status: string;
  statusTone: "brand" | "success" | "danger";
  reason: string;
  /** e.g. ["Nước ngọt: 2 → 0 (bỏ món)"] */
  lines: string[];
  oldSubtotalVnd: number;
  newSubtotalVnd: number;
  newTotalVnd: number;
  createdAt: string;
  answerBy: string;
  respondedAt: string | null;
};

export type FoodOrderListItem = {
  code: string;
  customer: string;
  store: string;
  regionLabel: string;
  items: string;
  lines: FoodOrderLine[];
  total: number;
  /** Delivery fee: suggestion vs customer offer / agreed fee (negotiated). */
  fee: {
    suggested: number | null;
    current: number;
    agreed: boolean;
    raiseCount: number;
    /** "Cho trả giá" | "Giá cố định" (null when the server did not say). */
    mode: string | null;
    offers: Array<{ id: string; driver: string; amount: number; status: string }>;
  };
  payment: string;
  driver: string | null;
  status: FoodOrderStatus;
  time: string;
  /** Store rejection reason shown to the customer, if any. */
  cancelReason: string | null;
  /** DEC-PROD-035: "Quán huỷ / từ chối" … (null unless cancelled). */
  cancelledBy: string | null;
  customerPhone: string | null;
  /** Real store pickup / customer dropoff coordinates for the route sketch. */
  pickupPoint: { lat: number; lng: number } | null;
  dropoffPoint: { lat: number; lng: number } | null;
  /** Latest merchant edit (detail only). */
  change: FoodOrderChangeSummary | null;
};
