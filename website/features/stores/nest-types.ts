/** Nest `OpsStoreListItem` — ops store directory. */
export type NestOpsStore = {
  id: string;
  name: string;
  ownerId: string;
  lat: number | null;
  lng: number | null;
  category?: string | null;
  createdAt: string;
  itemCount: number;
  /** Present when Nest exposes FoodStore.serviceRegionCode on list DTO. */
  serviceRegionCode?: string | null;
  /** Nest filter enums when returned on list/detail. */
  sale?: string | null;
  kyb?: string | null;
  /** DEC-PROD-026/027 — merchant intake mode and whether orders are accepted right now. */
  serviceMode?: "OPEN" | "BUSY" | "PAUSED";
  serviceModeUntil?: string | null;
  openNow?: boolean;
  closedReason?: "PAUSED" | "CLOSED" | null;
  /** DEC-PROD-028 — M022 order acceptance. */
  acceptSettings?: NestStoreAcceptSettings;
  estimatedPrepMinutes?: number;
};

export type NestStoreAcceptSettings = {
  acceptMode: "MANUAL" | "AUTO";
  maxActiveOrders: number | null;
  defaultPrepMinutes: number;
  busyExtraMinutes: number;
};

export type NestOpsStoreItem = {
  id: string;
  name: string;
  priceVnd: number;
  available: boolean;
};

export type NestOpsStoreDetail = NestOpsStore & {
  items: NestOpsStoreItem[];
};

export type NestOpsStorePage = {
  items: NestOpsStore[];
  page: number;
  limit: number;
  total: number;
};
