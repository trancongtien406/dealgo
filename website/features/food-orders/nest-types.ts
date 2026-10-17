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

export type NestFoodLine = {
  itemId: string;
  name: string;
  unitPriceVnd: number;
  quantity: number;
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
  assignedDriverId: string | null;
  lines: NestFoodLine[];
};

export type NestFoodOrderPage = {
  items: NestFoodOrderView[];
  page: number;
  limit: number;
  total: number;
};
