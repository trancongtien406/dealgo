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

export type FoodOrderListItem = {
  code: string;
  customer: string;
  store: string;
  regionLabel: string;
  items: string;
  lines: FoodOrderLine[];
  total: number;
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
};
