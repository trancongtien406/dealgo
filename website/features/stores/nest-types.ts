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
  address?: string | null;
  addressLabel?: string | null;
  ownerName?: string | null;
  ownerPhone?: string | null;
  ownerEmail?: string | null;
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
  soldCount?: number;
  imageUrl?: string | null;
  imageUrls?: string[];
  description?: string | null;
};

export type NestOpsStoreKybDetail = {
  applicationId: string;
  status: string;
  representativeName: string;
  businessType: string;
  registrationSubject: string;
  bankName: string;
  bankAccountNumber: string;
  bankAccountHolder: string;
  documentsWaived: boolean;
  documentCount: number;
  submittedAt: string | null;
  reviewedAt: string | null;
};

export type NestOpsStoreStats = {
  completedOrders: number;
  cancelledOrders: number;
  totalOrders: number;
  completionRate: number | null;
  ratingAverage: number | null;
  ratingCount: number;
};

export type NestOpsStoreRecentOrder = {
  id: string;
  code: string;
  status: string;
  statusLabel: string;
  totalVnd: number;
  dropoffLabel: string;
  customerName: string;
  createdAt: string;
};

export type NestOpsStoreRecentReview = {
  id: string;
  stars: number;
  comment: string | null;
  raterName: string;
  createdAt: string;
};

export type NestOpsStoreDetail = NestOpsStore & {
  items: NestOpsStoreItem[];
  kybDetail?: NestOpsStoreKybDetail | null;
  stats?: NestOpsStoreStats | null;
  recentOrders?: NestOpsStoreRecentOrder[];
  recentReviews?: NestOpsStoreRecentReview[];
};

export type NestOpsStorePage = {
  items: NestOpsStore[];
  page: number;
  limit: number;
  total: number;
};
