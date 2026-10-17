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
};
