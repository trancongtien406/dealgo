export const STORE_SALE_STATUSES = [
  "ACTIVE",
  "OPEN",
  "CLOSED",
  "PAUSED",
  "BUSY",
  "PENDING_APPROVAL",
  "SUSPENDED",
] as const;
export type StoreSaleStatus = (typeof STORE_SALE_STATUSES)[number];

export const STORE_KYB_STATUSES = [
  "APPROVED",
  "PENDING",
  "PENDING_KYB",
  "REJECTED",
  "NEEDS_VERIFY",
] as const;
export type StoreKybStatus = (typeof STORE_KYB_STATUSES)[number];

export type StoreListItem = {
  code: string;
  initials: string;
  name: string;
  category: string;
  owner: string;
  area: string;
  orders: number | null;
  rating: number | null;
  sale: StoreSaleStatus | null;
  kyb: StoreKybStatus | null;
  /** DEC-PROD-026: auto-resume time of a BUSY/PAUSED mode (ISO), when set. */
  serviceModeUntil: string | null;
  /** DEC-PROD-028: M022 intake line, e.g. "Tự động · tối đa 8 đơn"; null when not reported. */
  acceptSummary: string | null;
  /** Current kitchen estimate in minutes (default prep + BUSY extra). */
  prepMinutes: number | null;
  /** No map pin → cannot take delivery orders. */
  locationMissing: boolean;
  address?: string;
  phone?: string;
  email?: string;
  ownerName?: string;
  items?: StoreMenuItem[];
  kybDetail?: StoreKybDetail | null;
  stats?: StoreStats | null;
  recentOrders?: StoreRecentOrder[];
  recentReviews?: StoreRecentReview[];
};

export type StoreMenuItem = {
  id: string;
  name: string;
  priceVnd: number;
  available: boolean;
  soldCount?: number;
  imageUrl?: string | null;
  imageUrls?: string[];
  description?: string | null;
};

export type StoreKybDetail = {
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

export type StoreStats = {
  completedOrders: number;
  cancelledOrders: number;
  totalOrders: number;
  completionRate: number | null;
  ratingAverage: number | null;
  ratingCount: number;
};

export type StoreRecentOrder = {
  id: string;
  code: string;
  status: string;
  statusLabel: string;
  totalVnd: number;
  dropoffLabel: string;
  customerName: string;
  createdAt: string;
};

export type StoreRecentReview = {
  id: string;
  stars: number;
  comment: string | null;
  raterName: string;
  createdAt: string;
};
