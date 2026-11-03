import {
  type OpsDateWindow,
  inDateWindow,
} from '../operations/ops-date-window.js';
import { cancellationCountsAgainstDriver } from '../../shared/cancel-actor.js';
import type { CancelActorName } from '../../shared/cancel-actor.js';
import type { DriverJobCounts } from '../../shared/driver-job-counts.js';
import type {
  CompletionHook,
  TxHandle,
} from '../../shared/tx/completion-hook.js';
import { randomUUID } from 'node:crypto';
import { pageOffset } from '../../shared/pagination/pagination.js';
import {
  getServiceRegion,
  normalizeRegionFilter,
} from '../service-area/service-regions.js';
import { haversineKm } from '../ride/ride-geo.js';
import { FoodRuleError } from './food.error.js';

export interface ReadyNearFilter {
  lat: number;
  lng: number;
  radiusKm: number;
}

import {
  effectiveServiceMode,
  type StoreServiceMode,
  type StoreServiceState,
} from './store-service-mode.js';
import {
  ALWAYS_OPEN,
  closesAtToday,
  scheduleView,
  storeAvailability,
  type StoreAvailability,
  type StoreSchedule,
  type StoreScheduleView,
} from './store-schedule.js';
import {
  acceptSettingsFromRow,
  atCapacity,
  estimatedReadyAt,
  KITCHEN_ACTIVE_STATUSES,
  placementStatus,
  prepMinutesFor,
  type StoreAcceptSettings,
} from './store-accept.js';
import {
  OPEN_FOOD_STATUSES,
  type FoodOrderStatusName,
  type FoodCancelReasonCode,
  type FoodSystemCancelReason,
} from './food.constants.js';
import {
  VoucherRejectedError,
  type VoucherRedeemer,
} from '../promotion/promotion-redemption.js';
import {
  lineKey,
  normalizeOptionGroups,
  priceOptionSelection,
  type FoodLineOption,
  type FoodOptionGroupInput,
  type FoodOptionGroupView,
} from './food-options.js';

export type FoodLineView = {
  /** Line id, so the merchant can edit one line of an order. */
  id: string;
  itemId: string;
  name: string;
  /** Base price + chosen option deltas, per unit, at placement. */
  unitPriceVnd: number;
  quantity: number;
  /** Cover image snapshotted at placement (DEC-PROD-043). */
  imageUrl: string | null;
  /** Customer note for the kitchen; null = none. */
  note: string | null;
  /** Chosen options snapshotted at placement (DEC-PROD-033); [] when none. */
  options: FoodLineOption[];
};

export type StoreListItem = {
  id: string;
  name: string;
  ownerId: string;
  lat: number | null;
  lng: number | null;
  category: string | null;
  serviceRegionCode?: string | null;
  addressLabel?: string | null;
  /** M030 logo path (DEC-PROD-045); null = none uploaded. */
  logoUrl?: string | null;
  /** Merchant cover photo path; null = none (clients fall back to a dish photo). */
  coverUrl?: string | null;
  /** Merchant "about the store" text; null = none. */
  description?: string | null;
  /** Smallest food subtotal the store accepts; 0 = none. */
  minOrderVnd?: number;
};

export type StoreBrowseItem = StoreListItem &
  StoreAvailability & {
    createdAt: Date;
    distanceKm: number | null;
    serviceMode: StoreServiceMode;
    /** Closing time (HH:mm) of the shift taking orders now; null when not open (DEC-PROD-027). */
    closesAtToday: string | null;
    /** Cover thumb: first available menu item imageUrl (DEC-PROD-041). */
    imageUrl: string | null;
    /** Default prep + BUSY extra right now. */
    estimatedPrepMinutes: number;
    /** Raw average of visible store ratings (null = none); the service applies RATING_STORE_MIN_COUNT. */
    ratingAverage: number | null;
    ratingCount: number;
  };

export type StoreBrowsePage = {
  items: StoreBrowseItem[];
  total: number;
};

export type ListFoodStoresQuery = {
  page: number;
  limit: number;
  search?: string;
  category?: string;
  lat?: number;
  lng?: number;
  radiusKm: number;
  sortBy: 'name' | 'createdAt' | 'distance' | 'rating';
  /** Ratings below this count do not rank in sortBy=rating. */
  minRatingCount?: number;
};

export type StoreItemView = {
  id: string;
  name: string;
  priceVnd: number;
  /** List price shown struck through; null unless it is above priceVnd. */
  originalPriceVnd: number | null;
  available: boolean;
  /** M027 (DEC-PROD-039). */
  description: string | null;
  prepMinutes: number | null;
  imageUrl: string | null;
  /** Gallery URLs (DEC-PROD-042); cover is imageUrl / first entry. */
  imageUrls: string[];
  /** DELIVERED line qty sum (DEC-PROD-042). */
  soldCount: number;
  menuCategoryId: string | null;
  /** Option groups in display order (DEC-PROD-033); [] when the dish has none. */
  optionGroups: FoodOptionGroupView[];
  /** When the dish was added (ISO); the app marks recent ones as new. */
  addedAt: string | null;
  /** Merchant/ops views only; customer payloads drop unapproved dishes instead. */
  moderationStatus?: 'PENDING' | 'APPROVED' | 'REJECTED';
};

/** A dish surfaced on browse cards: the store's best sellers and its newest dish. */
export type StoreFeaturedItem = {
  id: string;
  name: string;
  priceVnd: number;
  originalPriceVnd: number | null;
  imageUrl: string | null;
  soldCount: number;
  addedAt: string;
};

/** Best sellers (sold > 0) first, then the newest dish when it is not already listed. */
export const STORE_FEATURED_BEST_SELLERS = 2;

export function pickFeaturedItems(
  items: StoreFeaturedItem[],
): StoreFeaturedItem[] {
  const best = items
    .filter((item) => item.soldCount > 0)
    .sort(
      (a, b) =>
        b.soldCount - a.soldCount ||
        b.addedAt.localeCompare(a.addedAt) ||
        a.id.localeCompare(b.id),
    )
    .slice(0, STORE_FEATURED_BEST_SELLERS);
  const newest = [...items].sort(
    (a, b) => b.addedAt.localeCompare(a.addedAt) || a.id.localeCompare(b.id),
  )[0];
  return newest && !best.some((item) => item.id === newest.id)
    ? [...best, newest]
    : best;
}

/** originalPriceVnd only counts while it is above the selling price. */
export function shownOriginalPrice(
  priceVnd: number,
  originalPriceVnd: number | null | undefined,
): number | null {
  return originalPriceVnd != null && originalPriceVnd > priceVnd
    ? originalPriceVnd
    : null;
}

export type StoreMenuSection = { id: string; name: string };

export type MenuCategoryView = {
  id: string;
  name: string;
  description: string | null;
  position: number;
  itemCount: number;
};

export type StoreDetail = StoreListItem &
  StoreServiceState &
  StoreAvailability & {
    /** M023 weekly hours / closed days / cut-off (DEC-PROD-027). */
    schedule: StoreScheduleView;
    /** Closing time (HH:mm) of the shift taking orders now; null when not open (DEC-PROD-027). */
    closesAtToday: string | null;
    /** M022 intake settings (DEC-PROD-028); stripped from the customer payload. */
    acceptSettings: StoreAcceptSettings;
    /** Default prep + BUSY extra right now; what customers see as the kitchen time. */
    estimatedPrepMinutes: number;
    /** Address the merchant set for pickup; shown on the store's info tab. */
    addressLabel?: string | null;
    items: StoreItemView[];
  };

export type UpdateStoreScheduleInput = {
  ownerId: string;
  schedule: StoreSchedule;
};

export type UpdateStoreServiceModeInput = {
  ownerId: string;
  mode: StoreServiceMode;
  until: Date | null;
  /** M024 BUSY extra prep minutes; undefined keeps the saved value. */
  busyExtraMinutes?: number;
};

export type UpdateStoreAcceptSettingsInput = {
  ownerId: string;
  acceptMode: StoreAcceptSettings['acceptMode'];
  maxActiveOrders: number | null;
  defaultPrepMinutes: number;
  /** Shared with M023 (StoreSchedule.lastOrderMinutes). */
  lastOrderMinutes: number;
};

export type OpsStoreSummary = StoreListItem &
  StoreServiceState &
  StoreAvailability & {
    createdAt: Date;
    itemCount: number;
    acceptSettings: StoreAcceptSettings;
    estimatedPrepMinutes: number;
  };

export type OpsStoreKybDetail = {
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

export type OpsStoreStats = {
  completedOrders: number;
  cancelledOrders: number;
  totalOrders: number;
  completionRate: number | null;
  ratingAverage: number | null;
  ratingCount: number;
};

export type OpsStoreRecentOrder = {
  id: string;
  code: string;
  status: string;
  statusLabel: string;
  totalVnd: number;
  dropoffLabel: string;
  customerName: string;
  createdAt: string;
};

export type OpsStoreRecentReview = {
  id: string;
  stars: number;
  comment: string | null;
  raterName: string;
  createdAt: string;
};

export type OpsStoreDetail = OpsStoreSummary & {
  items: StoreItemView[];
  kybDetail?: OpsStoreKybDetail | null;
  stats?: OpsStoreStats | null;
  recentOrders?: OpsStoreRecentOrder[];
  recentReviews?: OpsStoreRecentReview[];
};

export type OpsStorePage = {
  items: OpsStoreSummary[];
  total: number;
};

export type OpsCatalogModerationItem = {
  id: string;
  code: string;
  name: string;
  category: string;
  store: string;
  price: number;
  submittedAt: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  nameReady: boolean;
  imageReady: boolean;
};

export type OpsCatalogModerationPage = {
  items: OpsCatalogModerationItem[];
  total: number;
  page: number;
  limit: number;
};

/** Moderation rows show this when the store has no category yet. */
export const UNCATEGORIZED_STORE_CATEGORY_NAME = 'Khác';

/** M030 (DEC-PROD-045): undefined fields keep their current value. */
export type UpdateStoreProfileInput = {
  ownerId: string;
  name?: string;
  logoUrl?: string | null;
  coverUrl?: string | null;
  /** Trimmed text; null clears it. */
  description?: string | null;
  /** DEC-PROD-067: FoodCategory.code, already validated as active; null clears it. */
  category?: string | null;
  minOrderVnd?: number;
};

export type UpdateStoreLocationInput = {
  ownerId: string;
  lat: number;
  lng: number;
  /** Street address shown to drivers; omitted keeps the current value. */
  addressLabel?: string | null;
};

export type VoucherSponsor = 'PLATFORM' | 'MERCHANT' | 'SHARED';

export type FoodOrderView = {
  id: string;
  customerId: string;
  storeId: string;
  storeName: string | null;
  serviceRegionCode: string | null;
  ownerId: string;
  status: FoodOrderStatusName;
  deliveryFareVnd: number;
  subtotalVnd: number;
  /** Voucher discount snapshotted at placement; totalVnd is already net of it. */
  discountVnd: number;
  voucherCode: string | null;
  /** Internal accounting only (stripped from public payloads). */
  voucherSponsor: VoucherSponsor | null;
  totalVnd: number;
  dropoff: { lat: number; lng: number; label: string };
  /** Store pickup point when the store has coordinates (driver navigation, Admin route). */
  pickup: { lat: number; lng: number; label: string | null } | null;
  assignedDriverId: string | null;
  /** Set only when the merchant declined the order (DEC-PROD-021). */
  cancelReason: FoodCancelReason | null;
  /** DEC-PROD-035: who cancelled (null unless CANCELLED). */
  cancelledBy: CancelActorName | null;
  /** Customer note for the store / driver; null = none. */
  note: string | null;
  /** Cutlery requested with this order. */
  utensils: boolean;
  lines: FoodLineView[];
  /** Kitchen estimate snapshotted at placement (DEC-PROD-028); null on legacy orders. */
  prepMinutes: number | null;
  estimatedReadyAt: Date | null;
  /** When the driver picked the order up (null before / legacy). */
  pickedUpAt: Date | null;
  /** Set only when FAILED. */
  failReason: { code: string; note: string | null } | null;
  /** Cash the driver paid the store at pickup (snapshot). */
  merchantCashVnd: number | null;
  /** When the order was placed (Admin list time column, date filters). */
  createdAt: Date;
  updatedAt: Date;
  /** Checkout suggestion (reference only); deliveryFareVnd is the offer/agreed fee. */
  suggestedDeliveryFareVnd?: number | null;
  /** Set once a driver accepted the customer's offer or the customer selected a counter. */
  deliveryFareAgreedAt?: Date | null;
  deliveryFareRaiseCount?: number;
};

export type FoodDeliveryOfferStatusName =
  | 'PENDING'
  | 'SELECTED'
  | 'LOST'
  | 'WITHDRAWN';

/** A driver's counter on the delivery fee (the customer selects one). */
export type FoodDeliveryOfferView = {
  id: string;
  orderId: string;
  driverId: string;
  amountVnd: number;
  status: FoodDeliveryOfferStatusName;
  expiresAt: Date;
  editCount: number;
  createdAt: Date;
  updatedAt: Date;
};

/** Customer selects a driver counter: the claim also writes the agreed fee. */
export type FoodClaimFare = { offerId: string; customerId: string; now: Date };

export type SubmitFoodDeliveryOfferInput = {
  orderId: string;
  driverId: string;
  amountVnd: number;
  expiresAt: Date;
  /** Times a driver may change the counter (FOOD_MAX_OFFER_EDITS_PER_DRIVER). */
  maxEdits: number;
  /** Counter must be > the current offer and <= offer x this % (FOOD_COUNTER_MAX_PERCENT_OF_OFFER). */
  counterMaxPercent: number;
  /** Absolute ceiling (FOOD_MAX_DELIVERY_VND). */
  maxFareVnd: number;
  early: FoodEarlyClaim;
};

export type RaiseFoodDeliveryFareInput = {
  orderId: string;
  customerId: string;
  amountVnd: number;
  maxRaises: number;
};

/** Shared counter bound: offer < counter <= min(ceiling, offer x percent). */
export function counterCeilingVnd(
  offerVnd: number,
  counterMaxPercent: number,
  maxFareVnd: number,
): number {
  return Math.min(maxFareVnd, Math.floor((offerVnd * counterMaxPercent) / 100));
}

/** One edited line; toQuantity 0 removes it. */
export type FoodOrderChangeLine = {
  lineId: string;
  itemId: string;
  name: string;
  unitPriceVnd: number;
  fromQuantity: number;
  toQuantity: number;
};

export type FoodOrderChangeStatusName =
  'PENDING' | 'ACCEPTED' | 'REJECTED' | 'EXPIRED';

export type FoodOrderChangeView = {
  id: string;
  orderId: string;
  status: FoodOrderChangeStatusName;
  reasonCode: string;
  note: string | null;
  lines: FoodOrderChangeLine[];
  oldSubtotalVnd: number;
  newSubtotalVnd: number;
  newDiscountVnd: number;
  newTotalVnd: number;
  expiresAt: Date;
  respondedAt: Date | null;
  createdAt: Date;
};

export type ProposeFoodOrderChangeInput = {
  orderId: string;
  ownerId: string;
  reasonCode: string;
  note: string | null;
  lines: { lineId: string; toQuantity: number }[];
  expiresAt: Date;
};

export type FoodOrderChangeResult = {
  order: FoodOrderView;
  change: FoodOrderChangeView;
};

/** Failure input resolved by the service. */
export type FoodFailInput = {
  reasonCode: string;
  note: string | null;
  /** CUSTOMER_UNREACHABLE requires now - pickedUpAt >= this many minutes. */
  minWaitMinutes: number;
  now: Date;
};

export type FoodCancelReason = {
  code: FoodCancelReasonCode;
  note: string | null;
};

/** A PREPARING order may be claimed `leadMinutes` before its estimated ready time. */
export type FoodEarlyClaim = { leadMinutes: number; now: Date };

export type FoodTimeoutPolicy = {
  merchantAcceptMinutes: number;
  unclaimedReadyMinutes: number;
};
export type FoodTimedOut = { orderId: string; reason: FoodSystemCancelReason };

/** Driver history window: finished jobs, newest first. */
export type FoodDriverHistoryWindow = {
  before?: Date;
  since?: Date;
  limit: number;
};

export const DRIVER_HISTORY_FOOD_STATUSES = [
  'DELIVERED',
  'FAILED',
  'CANCELLED',
] as const;

export type CatalogItemInput = {
  name: string;
  priceVnd: number;
};

export type CreateCatalogItemInput = {
  ownerId: string;
  name: string;
  priceVnd: number;
  originalPriceVnd?: number | null;
  available?: boolean;
  /** Set by the service: PENDING unless item moderation is disabled. */
  moderationStatus?: 'PENDING' | 'APPROVED';
  description?: string | null;
  prepMinutes?: number | null;
  imageUrl?: string | null;
  menuCategoryId?: string | null;
};

export type UpdateCatalogItemInput = {
  imageUrls?: string[];
  ownerId: string;
  itemId: string;
  name?: string;
  priceVnd?: number;
  originalPriceVnd?: number | null;
  available?: boolean;
  description?: string | null;
  prepMinutes?: number | null;
  imageUrl?: string | null;
  menuCategoryId?: string | null;
};

export type MerchantHistoryFilter = {
  ownerId: string;
  page: number;
  limit: number;
  /** ALL | DELIVERED | CANCELLED | FAILED */
  tab?: string;
  q?: string;
  from?: Date;
  to?: Date;
};

export type MerchantHistoryRow = {
  id: string;
  status: string;
  subtotalVnd: number;
  totalVnd: number;
  createdAt: Date;
  finishedAt: Date;
  customerName: string | null;
  lineSummary: string;
};

export type ReplaceItemOptionsInput = {
  ownerId: string;
  itemId: string;
  groups: FoodOptionGroupInput[];
};

export type SetItemAvailabilityInput = {
  ownerId: string;
  itemId: string;
  available: boolean;
};

export type OpsFoodOrderPage = {
  items: FoodOrderView[];
  total: number;
};

export type ReadyOrderSummary = {
  id: string;
  storeId: string;
  /** PREPARING = early-claimable: ready within FOOD_EARLY_ASSIGN_LEAD_MINUTES. */
  status: 'READY' | 'PREPARING';
  estimatedReadyAt?: Date | null;
  storeName: string;
  storeAddress: string | null;
  deliveryFareVnd: number;
  subtotalVnd: number;
  totalVnd: number;
  dropoff: { lat: number; lng: number; label: string };
  /** Pickup coords (order snapshot, else store); dispatch radius prefers these over dropoff. */
  store: { lat: number; lng: number } | null;
  /** Where the driver collects the order (DEC-PROD-034 snapshot; legacy rows use the store). */
  pickup: { lat: number; lng: number; label: string | null } | null;
  lineCount: number;
};

export type OpsFoodInterveneResult = {
  order: FoodOrderView;
  auditId: string;
};

export type QueueOrderSummary = {
  id: string;
  storeId: string;
  status: (typeof OPEN_FOOD_STATUSES)[number];
  deliveryFareVnd: number;
  subtotalVnd: number;
  totalVnd: number;
  dropoff: { lat: number; lng: number; label: string };
  lineCount: number;
  /** QA M3: dishes by quantity (2× Phở = 2), what the merchant list shows. */
  itemCount: number;
  createdAt: Date;
  /** Internal: resolved to masked display names by FoodService, never returned. */
  customerId: string;
  assignedDriverId: string | null;
};

/** Raw rows for merchant stats; FoodService buckets them by Vietnam day. */
export type MerchantStatsRows = {
  finished: Array<{
    status: 'DELIVERED' | 'CANCELLED' | 'FAILED';
    subtotalVnd: number;
    finishedAt: Date;
  }>;
  openCount: number;
  topItems: Array<{ name: string; quantity: number }>;
};

/** One delivered order in a merchant statement window. */
export type MerchantStatementRow = {
  orderId: string;
  deliveredAt: Date;
  subtotalVnd: number;
  discountVnd: number;
  voucherSponsor: VoucherSponsor | null;
  /** Cash snapshot at pickup (null on orders picked up before the cash snapshot existed). */
  merchantCashVnd: number | null;
  /** Commission snapshot at delivery (null on older orders = 0). */
  commissionVnd: number | null;
};

/** Ops-recorded commission settlement for a store and ICT period. */
export type MerchantSettlementView = {
  id: string;
  storeId: string;
  /** YYYY-MM-DD (Asia/Ho_Chi_Minh), inclusive. */
  periodStart: string;
  periodEnd: string;
  orderCount: number;
  grossVnd: number;
  merchantFundedVnd: number;
  commissionVnd: number;
  netVnd: number;
  actorUserId: string;
  note: string | null;
  createdAt: Date;
};

export type RecordMerchantSettlementInput = Omit<
  MerchantSettlementView,
  'id' | 'createdAt'
> & {
  reason: string;
};

/** Sandbox demo store pin (Hải Châu, Đà Nẵng). */
export const FIXTURE_STORE_PIN = {
  lat: 16.0544,
  lng: 108.2022,
  label: 'Hải Châu, Đà Nẵng',
} as const;

export type PlaceFoodLineInput = {
  itemId: string;
  quantity: number;
  optionIds?: string[];
  /** Customer note for this line; blank/whitespace-only is normalized to null upstream. */
  note?: string | null;
};

export type PlaceFoodInput = {
  customerId: string;
  storeId: string;
  idempotencyKey: string;
  items: PlaceFoodLineInput[];
  dropoff: { lat: number; lng: number; label: string };
  /** Customer's delivery-fee offer (validated by the service against the suggestion). */
  deliveryFareVnd: number;
  /** Customer note for the store / driver; null = none. */
  note?: string | null;
  /** Cutlery requested with this order; omitted falls back to the column default. */
  utensils?: boolean;
  /** When false, items skip the moderation gate (platform setting FOOD_ITEM_MODERATION_ENABLED off). */
  requireApprovedItems?: boolean;
  /** System suggestion shown at checkout (reference only). */
  suggestedDeliveryFareVnd?: number;
  /** Re-validated and redeemed in the same unit of work as the order. */
  voucherCode?: string;
};

export interface FoodRepository {
  hasStore(): Promise<boolean>;
  createFixtureStore(ownerId: string, items: CatalogItemInput[]): Promise<void>;
  listStores(query: ListFoodStoresQuery): Promise<StoreBrowsePage>;
  listStoresPage(
    page: number,
    limit: number,
    filter?: {
      q?: string;
      status?: string;
      sale?: string;
      region?: string;
      category?: string;
      kyb?: string;
      /** MISSING = stores without map coordinates. */
      location?: string;
    },
  ): Promise<OpsStorePage>;
  listCatalogModeration(query: {
    page?: number;
    limit?: number;
    q?: string;
    store?: string;
    category?: string;
    status?: string;
    window?: OpsDateWindow;
  }): Promise<OpsCatalogModerationPage>;
  findStore(storeId: string): Promise<StoreDetail | null>;
  findStoreForOps(storeId: string): Promise<OpsStoreDetail | null>;
  findStoreByOwner(ownerId: string): Promise<StoreDetail | null>;
  ensureOwnedStore(ownerId: string, name: string): Promise<StoreDetail>;
  updateStoreLocation(input: UpdateStoreLocationInput): Promise<StoreDetail>;
  updateStoreProfile(input: UpdateStoreProfileInput): Promise<StoreDetail>;
  findStoreLogoUrl(storeId: string): Promise<string | null>;
  findStoreCoverUrl(storeId: string): Promise<string | null>;
  updateStoreServiceMode(
    input: UpdateStoreServiceModeInput,
  ): Promise<StoreDetail>;
  updateStoreSchedule(input: UpdateStoreScheduleInput): Promise<StoreDetail>;
  updateStoreAcceptSettings(
    input: UpdateStoreAcceptSettingsInput,
  ): Promise<StoreDetail>;
  listMenuCategories(ownerId: string): Promise<MenuCategoryView[]>;
  /** Customer menu sections of a store, in merchant order (empty sections omitted). */
  listStoreMenuSections(storeId: string, approvedOnly?: boolean): Promise<StoreMenuSection[]>;
  /** Approved, available dishes for browse cards, picked per store with pickFeaturedItems. */
  listFeaturedItems(
    storeIds: string[],
  ): Promise<Map<string, StoreFeaturedItem[]>>;
  createMenuCategory(input: {
    ownerId: string;
    name: string;
    description?: string | null;
  }): Promise<MenuCategoryView>;
  updateMenuCategory(input: {
    ownerId: string;
    categoryId: string;
    name?: string;
    description?: string | null;
  }): Promise<MenuCategoryView>;
  deleteMenuCategory(
    ownerId: string,
    categoryId: string,
  ): Promise<{ deleted: true }>;
  reorderMenuCategories(
    ownerId: string,
    orderedIds: string[],
  ): Promise<MenuCategoryView[]>;
  listMerchantHistory(filter: MerchantHistoryFilter): Promise<{
    items: MerchantHistoryRow[];
    page: number;
    limit: number;
    total: number;
    deliveredCount: number;
    deliveredRevenueVnd: number;
  }>;
  createItem(input: CreateCatalogItemInput): Promise<StoreItemView>;
  updateItem(input: UpdateCatalogItemInput): Promise<StoreItemView>;
  /** Public image serve: current imageUrl for an item id, or null. */
  findItemImageUrl(itemId: string): Promise<string | null>;
  findItemImageUrls(itemId: string): Promise<string[]>;
  setItemAvailability(input: SetItemAvailabilityInput): Promise<StoreItemView>;
  /** Replaces the item's option groups (ids on this item are kept). */
  replaceItemOptions(input: ReplaceItemOptionsInput): Promise<StoreItemView>;
  setCatalogModeration(
    itemId: string,
    decision: 'APPROVED' | 'REJECTED',
  ): Promise<{
    id: string;
    available: boolean;
    moderationStatus: string;
  } | null>;
  place(input: PlaceFoodInput): Promise<FoodOrderView>;
  findOrder(orderId: string): Promise<FoodOrderView | null>;
  /**
   * Oldest-first READY, unassigned orders. With `near`, only orders whose pickup point
   * (pickup ?? store ?? dropoff) lies within `radiusKm` are counted toward `limit`, so new
   * nearby orders are not hidden behind a backlog of far-away older ones.
   */
  listReady(
    limit?: number,
    near?: ReadyNearFilter,
    early?: FoodEarlyClaim,
  ): Promise<ReadyOrderSummary[]>;
  listQueue(ownerId: string): Promise<QueueOrderSummary[]>;
  /** Owner-scoped finished orders since `since` (by last status change), open count, top items. */
  merchantStats(
    ownerId: string,
    since: Date,
    topLimit: number,
  ): Promise<MerchantStatsRows>;
  /** DELIVERED orders of a store finished in [from, to). */
  deliveredForStatement(
    storeId: string,
    from: Date,
    to: Date,
  ): Promise<MerchantStatementRow[]>;
  listMerchantSettlements(
    storeId: string,
    limit: number,
  ): Promise<MerchantSettlementView[]>;
  /** Rejects overlapping periods (FOOD_SETTLEMENT_OVERLAP); writes the Ops audit row. */
  recordMerchantSettlement(
    input: RecordMerchantSettlementInput,
  ): Promise<MerchantSettlementView>;
  listOrdersPage(
    page: number,
    limit: number,
    filter?: {
      status?: string;
      statuses?: string[];
      q?: string;
      store?: string;
      payment?: string;
      zone?: string;
      window?: OpsDateWindow;
    },
  ): Promise<OpsFoodOrderPage>;
  listOrdersForCustomer(
    customerId: string,
    page: number,
    limit: number,
  ): Promise<OpsFoodOrderPage>;
  /** DELIVERED/FAILED/CANCELLED orders still assigned to the driver, newest updatedAt first. */
  listFinishedForDriver(
    driverId: string,
    window: FoodDriverHistoryWindow,
  ): Promise<FoodOrderView[]>;
  /** Order ids assigned to the driver in one of [statuses] (live location fan-out). */
  listIdsForDriverInStatuses?(
    driverId: string,
    statuses: readonly string[],
  ): Promise<string[]>;
  /** Customer's order ids in one of [statuses], newest first (relaunch resume, DEC-PROD-057). */
  listIdsForCustomerInStatuses?(
    customerId: string,
    statuses: readonly string[],
  ): Promise<string[]>;
  /** Lifetime DELIVERED / terminal order counts per assigned driver (Admin stats). */
  countFinishedForDrivers(
    driverIds: readonly string[],
  ): Promise<Map<string, DriverJobCounts>>;
  accept(orderId: string, ownerId: string): Promise<FoodOrderView>;
  markReady(orderId: string, ownerId: string): Promise<FoodOrderView>;
  /**
   * Driver accepts the customer's current delivery-fee offer (no `fare`), or the customer
   * selects a driver counter (`fare`): atomic assignment; the other pending counters → LOST.
   */
  claim(
    orderId: string,
    driverId: string,
    maxConcurrentJobs?: number,
    early?: FoodEarlyClaim,
    fare?: FoodClaimFare,
  ): Promise<FoodOrderView>;
  /** Driver creates/updates a counter on an open, unassigned order (one per driver). */
  submitDeliveryOffer(
    input: SubmitFoodDeliveryOfferInput,
  ): Promise<FoodDeliveryOfferView>;
  /** Driver withdraws a pending counter. */
  withdrawDeliveryOffer(
    orderId: string,
    driverId: string,
  ): Promise<FoodDeliveryOfferView>;
  /** Every counter on the order, newest first. */
  listDeliveryOffers(orderId: string): Promise<FoodDeliveryOfferView[]>;
  /** Customer raises the offer while no driver is assigned (re-post). */
  raiseDeliveryFare(input: RaiseFoodDeliveryFareInput): Promise<FoodOrderView>;
  /** Assigned driver hands the order back before pickup (counts as a driver cancel). */
  release(
    orderId: string,
    driverId: string,
    reasonCode: string,
  ): Promise<FoodOrderView>;
  /** Worker: PLACED never accepted → MERCHANT_TIMEOUT; READY never claimed → NO_DRIVER. */
  timeoutDue(
    now: Date,
    policy: FoodTimeoutPolicy,
    limit?: number,
  ): Promise<FoodTimedOut[]>;
  /** Snapshots pickedUpAt + merchantCashVnd (cash paid to the store). */
  pickup(
    orderId: string,
    driverId: string,
    snapshot?: { merchantCashVnd: number; at: Date },
  ): Promise<FoodOrderView>;
  /** Commission snapshot written inside the delivery transaction. */
  snapshotCommissionWithin(
    tx: TxHandle,
    orderId: string,
    input: { commissionBps: number; commissionVnd: number },
  ): Promise<void>;
  /** `onDelivered` runs in the delivery transaction; if it throws the order stays PICKED_UP. */
  deliver(
    orderId: string,
    driverId: string,
    onDelivered?: CompletionHook<FoodOrderView>,
  ): Promise<FoodOrderView>;
  /** Only after pickup, with a reason; `onFailed` runs in the same transaction. */
  fail(
    orderId: string,
    driverId: string,
    input: FoodFailInput,
    onFailed?: CompletionHook<FoodOrderView>,
  ): Promise<FoodOrderView>;
  cancel(orderId: string, customerId: string): Promise<FoodOrderView>;
  /**
   * Merchant edits a PLACED/PREPARING order (lower quantities / remove lines).
   * One PENDING change per order (FOOD_CHANGE_PENDING); ready is blocked until it is answered.
   */
  proposeChange(
    input: ProposeFoodOrderChangeInput,
  ): Promise<FoodOrderChangeResult>;
  /** Latest change of the order (any status), or null. */
  latestChange(orderId: string): Promise<FoodOrderChangeView | null>;
  /** Customer answers the PENDING change: accept applies it, reject cancels the order (no fee). */
  respondChange(
    orderId: string,
    customerId: string,
    changeId: string,
    accept: boolean,
    now: Date,
  ): Promise<FoodOrderChangeResult>;
  /** Worker: PENDING changes past expiresAt → EXPIRED and the order CANCELLED (SYSTEM). */
  expireChanges(now: Date, limit?: number): Promise<string[]>;
  /** Store owner declines a PLACED order (→ CANCELLED, voucher released). */
  reject(
    orderId: string,
    ownerId: string,
    reason: FoodCancelReason,
  ): Promise<FoodOrderView>;
  opsCancel(
    orderId: string,
    actorUserId: string,
    reason: string,
  ): Promise<OpsFoodInterveneResult>;
  opsReassign(
    orderId: string,
    actorUserId: string,
    reason: string,
  ): Promise<OpsFoodInterveneResult>;
}

type CatalogModerationStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

type StoredStore = StoreListItem & {
  createdAt: Date;
  addressLabel?: string | null;
  serviceMode?: StoreServiceMode;
  serviceModeUntil?: Date | null;
  schedule?: StoreSchedule;
  accept?: StoreAcceptSettings;
};

function memoryAccept(
  store: StoredStore,
): Pick<StoreDetail, 'acceptSettings' | 'estimatedPrepMinutes'> {
  const acceptSettings = store.accept ?? acceptSettingsFromRow({});
  const mode = effectiveServiceMode(
    store.serviceMode,
    store.serviceModeUntil,
  ).serviceMode;
  return {
    acceptSettings: { ...acceptSettings },
    estimatedPrepMinutes: prepMinutesFor(acceptSettings, mode),
  };
}

function memoryAvailability(
  store: StoredStore,
  now = new Date(),
): StoreAvailability {
  return storeAvailability(
    store.serviceMode,
    store.serviceModeUntil,
    store.schedule ?? ALWAYS_OPEN,
    now,
  );
}

function closesAtTodayWhenOpen(
  store: StoredStore,
  availability: StoreAvailability,
  now: Date,
): string | null {
  return availability.openNow
    ? closesAtToday(store.schedule ?? ALWAYS_OPEN, now)
    : null;
}
type StoredItem = Omit<StoreItemView, 'addedAt' | 'originalPriceVnd'> & {
  originalPriceVnd?: number | null;
  storeId: string;
  moderationStatus: CatalogModerationStatus;
  createdAt?: Date;
};
type StoredOrder = FoodOrderView & {
  merchantCommissionBps?: number | null;
  merchantCommissionVnd?: number | null;
  idempotencyKey: string;
  createdAt: Date;
  acceptedAt?: Date | null;
  readyAt?: Date | null;
};

/** Earliest instant a PREPARING order may be claimed; null = not early-claimable. */
export function earlyClaimOpensAt(
  order: {
    prepMinutes: number | null;
    createdAt: Date;
    acceptedAt?: Date | null;
  },
  leadMinutes: number,
): Date | null {
  if (order.prepMinutes === null || order.prepMinutes === undefined) {
    return null;
  }
  const start = (order.acceptedAt ?? order.createdAt).getTime();
  return new Date(
    start + (order.prepMinutes - Math.max(0, leadMinutes)) * 60_000,
  );
}

export type MemoryDriverJobCancellation = {
  orderId: string;
  driverId: string;
  reasonCode: string;
  fromStatus: string;
  createdAt: Date;
};

function touchOrder(order: StoredOrder): void {
  order.updatedAt = new Date();
}

const OPEN = new Set<string>(OPEN_FOOD_STATUSES);

export class MemoryFoodRepository implements FoodRepository {
  constructor(private readonly vouchers?: VoucherRedeemer) {}

  private readonly stores: StoredStore[] = [];
  private readonly items: StoredItem[] = [];
  private readonly deliveryOffers: FoodDeliveryOfferView[] = [];
  private readonly seededAt = new Date();
  private lastItemCreatedAt = this.seededAt.getTime();

  /** Strictly increasing so "newest dish" never ties with seeded items in the same ms. */
  private nextItemCreatedAt(): Date {
    this.lastItemCreatedAt = Math.max(Date.now(), this.lastItemCreatedAt + 1);
    return new Date(this.lastItemCreatedAt);
  }
  private readonly orders: StoredOrder[] = [];

  async listIdsForDriverInStatuses(
    driverId: string,
    statuses: readonly string[],
  ): Promise<string[]> {
    return this.orders
      .filter(
        (order) =>
          order.assignedDriverId === driverId &&
          statuses.includes(order.status),
      )
      .map((order) => order.id);
  }

  async listIdsForCustomerInStatuses(
    customerId: string,
    statuses: readonly string[],
  ): Promise<string[]> {
    return this.orders
      .filter(
        (order) =>
          order.customerId === customerId && statuses.includes(order.status),
      )
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .map((order) => order.id);
  }

  async hasStore(): Promise<boolean> {
    return this.stores.length > 0;
  }

  async createFixtureStore(
    ownerId: string,
    items: CatalogItemInput[],
  ): Promise<void> {
    if (this.stores.length > 0) {
      return;
    }
    const storeId = randomUUID();
    this.stores.push({
      id: storeId,
      name: 'Bún Bò Huế',
      ownerId,
      lat: FIXTURE_STORE_PIN.lat,
      lng: FIXTURE_STORE_PIN.lng,
      addressLabel: FIXTURE_STORE_PIN.label,
      category: 'pho',
      createdAt: new Date(),
    });
    for (const item of items) {
      this.items.push({
        id: randomUUID(),
        storeId,
        name: item.name,
        priceVnd: item.priceVnd,
        available: true,
        moderationStatus: 'APPROVED',
        description: null,
        prepMinutes: null,
        imageUrl: null,
        imageUrls: [],
        soldCount: 0,
        menuCategoryId: null,
        optionGroups: [],
      });
    }
  }

  async listStores(query: ListFoodStoresQuery): Promise<StoreBrowsePage> {
    const search = query.search?.trim().toLowerCase();
    const category = query.category?.trim().toLowerCase();
    const hasGeo = query.lat !== undefined && query.lng !== undefined;
    const origin = hasGeo ? { lat: query.lat!, lng: query.lng! } : null;

    // Stores without coordinates are not orderable, so browse hides them.
    let filtered = this.stores
      .filter((store) => store.lat != null && store.lng != null)
      .map((store) => {
        const distanceKm =
          origin && store.lat !== null && store.lng !== null
            ? haversineKm(origin, { lat: store.lat, lng: store.lng })
            : null;
        return { store, distanceKm };
      });

    if (search) {
      filtered = filtered.filter(
        (entry) =>
          entry.store.name.toLowerCase().includes(search) ||
          this.items.some(
            (item) =>
              item.storeId === entry.store.id &&
              item.name.toLowerCase().includes(search),
          ),
      );
    }
    if (category) {
      filtered = filtered.filter(
        (entry) => entry.store.category?.toLowerCase() === category,
      );
    }
    if (origin) {
      filtered = filtered.filter(
        (entry) =>
          entry.distanceKm !== null && entry.distanceKm <= query.radiusKm,
      );
    }

    const sortBy =
      query.sortBy === 'distance' && !origin ? 'createdAt' : query.sortBy;
    const now = new Date();
    const open = new Map(
      filtered.map((entry) => [
        entry.store.id,
        memoryAvailability(entry.store, now),
      ]),
    );
    filtered.sort((left, right) => {
      // DEC-PROD-027: open stores first; paused/closed stay listed with a label.
      const openRank =
        Number(open.get(right.store.id)!.openNow) -
        Number(open.get(left.store.id)!.openNow);
      if (openRank !== 0) {
        return openRank;
      }
      if (sortBy === 'name') {
        return (
          left.store.name.localeCompare(right.store.name) ||
          left.store.id.localeCompare(right.store.id)
        );
      }
      if (sortBy === 'distance') {
        const leftDistance = left.distanceKm ?? Number.POSITIVE_INFINITY;
        const rightDistance = right.distanceKm ?? Number.POSITIVE_INFINITY;
        return (
          leftDistance - rightDistance ||
          left.store.id.localeCompare(right.store.id)
        );
      }
      return (
        right.store.createdAt.getTime() - left.store.createdAt.getTime() ||
        left.store.id.localeCompare(right.store.id)
      );
    });

    const total = filtered.length;
    const start = pageOffset(query.page, query.limit);
    const items = filtered.slice(start, start + query.limit).map((entry) => {
      const availability = open.get(entry.store.id)!;
      return {
        ...toStoreListItem(entry.store),
        ...availability,
        closesAtToday: closesAtTodayWhenOpen(entry.store, availability, now),
        serviceMode: effectiveServiceMode(
          entry.store.serviceMode,
          entry.store.serviceModeUntil,
        ).serviceMode,
        createdAt: entry.store.createdAt,
        distanceKm: entry.distanceKm,
        imageUrl:
          entry.store.coverUrl ?? coverImageForStore(this.items, entry.store.id),
        estimatedPrepMinutes: memoryAccept(entry.store).estimatedPrepMinutes,
        ratingAverage: null,
        ratingCount: 0,
      };
    });
    return { items, total };
  }

  async listStoresPage(
    page: number,
    limit: number,
    filter?: {
      q?: string;
      status?: string;
      sale?: string;
      region?: string;
      category?: string;
      kyb?: string;
      /** MISSING = stores without map coordinates. */
      location?: string;
    },
  ): Promise<OpsStorePage> {
    let filtered = [...this.stores];
    if (filter?.q && filter.q.trim()) {
      const q = filter.q.trim().toLowerCase();
      filtered = filtered.filter(
        (s) =>
          s.name.toLowerCase().includes(q) || s.id.toLowerCase().includes(q),
      );
    }
    const regionCode = normalizeRegionFilter(filter?.region);
    if (regionCode) {
      const label =
        getServiceRegion(regionCode)?.label.toLowerCase() ??
        regionCode.toLowerCase();
      filtered = filtered.filter((s) => s.name.toLowerCase().includes(label));
    }
    if (filter?.category && filter.category !== 'ALL') {
      const c = filter.category;
      filtered = filtered.filter((s) => s.category === c);
    }
    if (filter?.location === 'MISSING') {
      filtered = filtered.filter((s) => s.lat == null || s.lng == null);
    }
    const sorted = filtered.sort(
      (left, right) =>
        right.createdAt.getTime() - left.createdAt.getTime() ||
        left.id.localeCompare(right.id),
    );
    const total = sorted.length;
    const start = (page - 1) * limit;
    return {
      total,
      items: sorted
        .slice(start, start + limit)
        .map((store) => this.toOpsStoreSummary(store)),
    };
  }

  async listCatalogModeration(query: {
    page?: number;
    limit?: number;
    q?: string;
    store?: string;
    category?: string;
    status?: string;
    window?: OpsDateWindow;
  }): Promise<OpsCatalogModerationPage> {
    const combined: OpsCatalogModerationItem[] = [];
    for (const item of this.items) {
      const st = this.stores.find((s) => s.id === item.storeId);
      combined.push({
        id: item.id,
        code: `SP-${item.id.slice(0, 5).toUpperCase()}`,
        name: item.name,
        category: st?.category ?? UNCATEGORIZED_STORE_CATEGORY_NAME,
        store: st ? st.name : 'Cửa hàng DealGo',
        price: item.priceVnd,
        submittedAt: (item.createdAt ?? this.seededAt).toISOString(),
        status: item.moderationStatus,
        nameReady: true,
        imageReady: true,
      });
    }
    return filterCatalogModerationItems(combined, query);
  }

  async findStore(storeId: string): Promise<StoreDetail | null> {
    const store = this.stores.find((entry) => entry.id === storeId);
    if (!store) {
      return null;
    }
    const now = new Date();
    const availability = memoryAvailability(store, now);
    return {
      ...toStoreListItem(store),
      ...effectiveServiceMode(store.serviceMode, store.serviceModeUntil),
      ...availability,
      closesAtToday: closesAtTodayWhenOpen(store, availability, now),
      schedule: scheduleView(store.schedule ?? ALWAYS_OPEN),
      ...memoryAccept(store),
      addressLabel: store.addressLabel ?? null,
      items: this.items
        .filter((item) => item.storeId === storeId)
        .map(memoryItemView),
    };
  }

  async findStoreForOps(storeId: string): Promise<OpsStoreDetail | null> {
    const store = this.stores.find((entry) => entry.id === storeId);
    if (!store) {
      return null;
    }
    const items = this.items
      .filter((item) => item.storeId === storeId)
      .map(memoryItemView);
    return {
      ...this.toOpsStoreSummary(store),
      items,
    };
  }

  async place(input: PlaceFoodInput): Promise<FoodOrderView> {
    const existing = this.orders.find(
      (order) =>
        order.customerId === input.customerId &&
        order.idempotencyKey === input.idempotencyKey,
    );
    if (existing) {
      return copyOrder(existing);
    }
    if (
      this.orders.some(
        (order) =>
          order.customerId === input.customerId && OPEN.has(order.status),
      )
    ) {
      throw new FoodRuleError('FOOD_ORDER_ALREADY_OPEN');
    }
    const store = this.stores.find((entry) => entry.id === input.storeId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const availability = memoryAvailability(store);
    if (availability.closedReason === 'PAUSED') {
      throw new FoodRuleError('FOOD_STORE_PAUSED');
    }
    if (availability.closedReason === 'CLOSED') {
      throw new FoodRuleError('FOOD_STORE_CLOSED');
    }
    const { acceptSettings, estimatedPrepMinutes } = memoryAccept(store);
    const kitchen = new Set<string>(KITCHEN_ACTIVE_STATUSES);
    const active = this.orders.filter(
      (order) => order.storeId === store.id && kitchen.has(order.status),
    ).length;
    if (atCapacity(acceptSettings, active)) {
      throw new FoodRuleError('FOOD_STORE_AT_CAPACITY');
    }
    const lines = this.snapshotLines(
      input.storeId,
      input.items,
      input.requireApprovedItems ?? true,
    );
    const subtotalVnd = lines.reduce(
      (sum, line) => sum + line.unitPriceVnd * line.quantity,
      0,
    );
    if (subtotalVnd < (store.minOrderVnd ?? 0)) {
      throw new FoodRuleError('FOOD_MIN_ORDER_NOT_MET');
    }
    const orderId = randomUUID();
    let discountVnd = 0;
    let voucherCode: string | null = null;
    let voucherSponsor: VoucherSponsor | null = null;
    if (input.voucherCode) {
      if (!this.vouchers) {
        throw new VoucherRejectedError(
          'VOUCHER_NOT_FOUND',
          'Vouchers are not configured',
        );
      }
      const redeemed = await this.vouchers.redeem({
        code: input.voucherCode,
        userId: input.customerId,
        serviceType: 'FOOD',
        orderAmount: subtotalVnd,
        deliveryFee: input.deliveryFareVnd,
        storeId: store.id,
        entityType: 'FOOD_ORDER',
        entityId: orderId,
      });
      discountVnd = redeemed.discountVnd;
      voucherCode = redeemed.code;
      voucherSponsor = redeemed.sponsor;
    }
    const placedAt = new Date();
    const order: StoredOrder = {
      id: orderId,
      customerId: input.customerId,
      storeId: store.id,
      storeName: store.name,
      pickup:
        store.lat != null && store.lng != null
          ? {
              lat: store.lat,
              lng: store.lng,
              label: store.addressLabel ?? null,
            }
          : null,
      serviceRegionCode: store.serviceRegionCode ?? null,
      ownerId: store.ownerId,
      status: placementStatus(acceptSettings),
      deliveryFareVnd: input.deliveryFareVnd,
      suggestedDeliveryFareVnd:
        input.suggestedDeliveryFareVnd ?? input.deliveryFareVnd,
      deliveryFareAgreedAt: null,
      deliveryFareRaiseCount: 0,
      subtotalVnd,
      discountVnd,
      voucherCode,
      voucherSponsor,
      totalVnd: Math.max(0, subtotalVnd + input.deliveryFareVnd - discountVnd),
      dropoff: { ...input.dropoff },
      assignedDriverId: null,
      cancelReason: null,
      cancelledBy: null,
      note: input.note ?? null,
      utensils: input.utensils ?? true,
      lines,
      prepMinutes: estimatedPrepMinutes,
      estimatedReadyAt: estimatedReadyAt(placedAt, estimatedPrepMinutes),
      pickedUpAt: null,
      failReason: null,
      merchantCashVnd: null,
      idempotencyKey: input.idempotencyKey,
      createdAt: placedAt,
      updatedAt: placedAt,
    };
    this.orders.push(order);
    return copyOrder(order);
  }

  async findOrder(orderId: string): Promise<FoodOrderView | null> {
    const order = this.orders.find((entry) => entry.id === orderId);
    return order ? copyOrder(order) : null;
  }

  async listReady(
    limit?: number,
    near?: ReadyNearFilter,
    early?: FoodEarlyClaim,
  ): Promise<ReadyOrderSummary[]> {
    const earlyOpen = (order: StoredOrder): boolean => {
      const opensAt = early
        ? earlyClaimOpensAt(order, early.leadMinutes)
        : null;
      return !!early && !!opensAt && opensAt.getTime() <= early.now.getTime();
    };
    let rows = this.orders
      .filter(
        (order) =>
          order.assignedDriverId === null &&
          (order.status === 'READY' ||
            (order.status === 'PREPARING' && earlyOpen(order))),
      )
      .sort(byCreatedAt)
      .map((order) => {
        const store = this.stores.find((entry) => entry.id === order.storeId);
        const pickup = order.pickup
          ? { ...order.pickup }
          : store?.lat != null && store?.lng != null
            ? {
                lat: store.lat,
                lng: store.lng,
                label: store.addressLabel ?? null,
              }
            : null;
        return {
          id: order.id,
          storeId: order.storeId,
          status:
            order.status === 'PREPARING'
              ? ('PREPARING' as const)
              : ('READY' as const),
          estimatedReadyAt: order.estimatedReadyAt,
          storeName: store?.name ?? order.storeName ?? '',
          storeAddress: store?.addressLabel ?? null,
          deliveryFareVnd: order.deliveryFareVnd,
          subtotalVnd: order.subtotalVnd,
          totalVnd: order.totalVnd,
          dropoff: { ...order.dropoff },
          store: pickup ? { lat: pickup.lat, lng: pickup.lng } : null,
          pickup,
          lineCount: order.lines.length,
        };
      });
    if (near) {
      const origin = { lat: near.lat, lng: near.lng };
      rows = rows.filter(
        (row) => haversineKm(origin, row.store ?? row.dropoff) <= near.radiusKm,
      );
    }
    if (limit !== undefined && Number.isSafeInteger(limit) && limit > 0) {
      return rows.slice(0, limit);
    }
    return rows;
  }

  async listQueue(ownerId: string): Promise<QueueOrderSummary[]> {
    return this.orders
      .filter(
        (
          order,
        ): order is StoredOrder & { status: QueueOrderSummary['status'] } =>
          order.ownerId === ownerId && OPEN.has(order.status),
      )
      .sort(byCreatedAt)
      .map((order) => ({
        id: order.id,
        storeId: order.storeId,
        status: order.status,
        deliveryFareVnd: order.deliveryFareVnd,
        subtotalVnd: order.subtotalVnd,
        totalVnd: order.totalVnd,
        dropoff: { ...order.dropoff },
        lineCount: order.lines.length,
        itemCount: order.lines.reduce((sum, line) => sum + line.quantity, 0),
        createdAt: new Date(order.createdAt),
        customerId: order.customerId,
        assignedDriverId: order.assignedDriverId,
      }));
  }

  async merchantStats(
    ownerId: string,
    since: Date,
    topLimit: number,
  ): Promise<MerchantStatsRows> {
    const owned = this.orders.filter((order) => order.ownerId === ownerId);
    const finished = owned.flatMap((order) =>
      (order.status === 'DELIVERED' ||
        order.status === 'CANCELLED' ||
        order.status === 'FAILED') &&
      order.updatedAt >= since
        ? [
            {
              status: order.status,
              subtotalVnd: order.subtotalVnd,
              finishedAt: new Date(order.updatedAt),
            },
          ]
        : [],
    );
    const quantities = new Map<string, number>();
    for (const order of owned) {
      if (order.status !== 'DELIVERED' || order.updatedAt < since) {
        continue;
      }
      for (const line of order.lines) {
        quantities.set(
          line.name,
          (quantities.get(line.name) ?? 0) + line.quantity,
        );
      }
    }
    return {
      finished,
      openCount: owned.filter((order) => OPEN.has(order.status)).length,
      topItems: [...quantities.entries()]
        .map(([name, quantity]) => ({ name, quantity }))
        .sort((a, b) => b.quantity - a.quantity || a.name.localeCompare(b.name))
        .slice(0, topLimit),
    };
  }

  readonly merchantSettlements: MerchantSettlementView[] = [];

  async deliveredForStatement(
    storeId: string,
    from: Date,
    to: Date,
  ): Promise<MerchantStatementRow[]> {
    return this.orders
      .filter(
        (order) =>
          order.storeId === storeId &&
          order.status === 'DELIVERED' &&
          order.updatedAt >= from &&
          order.updatedAt < to,
      )
      .map((order) => ({
        orderId: order.id,
        deliveredAt: new Date(order.updatedAt),
        subtotalVnd: order.subtotalVnd,
        discountVnd: order.discountVnd,
        voucherSponsor: order.voucherSponsor ?? null,
        merchantCashVnd: order.merchantCashVnd ?? null,
        commissionVnd: order.merchantCommissionVnd ?? null,
      }));
  }

  async listMerchantSettlements(
    storeId: string,
    limit: number,
  ): Promise<MerchantSettlementView[]> {
    return this.merchantSettlements
      .filter((row) => row.storeId === storeId)
      .sort((a, b) => b.periodEnd.localeCompare(a.periodEnd))
      .slice(0, limit)
      .map((row) => ({ ...row }));
  }

  async recordMerchantSettlement(
    input: RecordMerchantSettlementInput,
  ): Promise<MerchantSettlementView> {
    const overlaps = this.merchantSettlements.some(
      (row) =>
        row.storeId === input.storeId &&
        row.periodStart <= input.periodEnd &&
        row.periodEnd >= input.periodStart,
    );
    if (!this.stores.some((store) => store.id === input.storeId)) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    if (overlaps) {
      throw new FoodRuleError('FOOD_SETTLEMENT_OVERLAP');
    }
    const { reason: _reason, ...rest } = input;
    const row: MerchantSettlementView = {
      ...rest,
      id: randomUUID(),
      createdAt: new Date(),
    };
    this.merchantSettlements.push(row);
    return { ...row };
  }

  async findStoreByOwner(ownerId: string): Promise<StoreDetail | null> {
    const store = this.stores.find((entry) => entry.ownerId === ownerId);
    if (!store) {
      return null;
    }
    return this.findStore(store.id);
  }

  async ensureOwnedStore(ownerId: string, name: string): Promise<StoreDetail> {
    const existing = await this.findStoreByOwner(ownerId);
    if (existing) {
      return existing;
    }
    const storeId = randomUUID();
    this.stores.push({
      id: storeId,
      name,
      ownerId,
      lat: null,
      lng: null,
      category: null,
      createdAt: new Date(),
    });
    return {
      id: storeId,
      name,
      ownerId,
      lat: null,
      lng: null,
      category: null,
      serviceMode: 'OPEN',
      serviceModeUntil: null,
      openNow: true,
      closedReason: null,
      closesAtToday: null,
      schedule: scheduleView(ALWAYS_OPEN),
      ...memoryAccept({
        id: storeId,
        name,
        ownerId,
        lat: null,
        lng: null,
        category: null,
        createdAt: new Date(),
      }),
      items: [],
    };
  }

  async updateStoreSchedule(
    input: UpdateStoreScheduleInput,
  ): Promise<StoreDetail> {
    const store = this.stores.find((entry) => entry.ownerId === input.ownerId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    store.schedule = input.schedule;
    const detail = await this.findStore(store.id);
    if (!detail) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    return detail;
  }

  async updateStoreAcceptSettings(
    input: UpdateStoreAcceptSettingsInput,
  ): Promise<StoreDetail> {
    const store = this.stores.find((entry) => entry.ownerId === input.ownerId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    store.accept = {
      ...(store.accept ?? acceptSettingsFromRow({})),
      acceptMode: input.acceptMode,
      maxActiveOrders: input.maxActiveOrders,
      defaultPrepMinutes: input.defaultPrepMinutes,
    };
    store.schedule = {
      ...(store.schedule ?? ALWAYS_OPEN),
      lastOrderMinutes: input.lastOrderMinutes,
    };
    const detail = await this.findStore(store.id);
    if (!detail) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    return detail;
  }

  async updateStoreServiceMode(
    input: UpdateStoreServiceModeInput,
  ): Promise<StoreDetail> {
    const store = this.stores.find((entry) => entry.ownerId === input.ownerId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    store.serviceMode = input.mode;
    store.serviceModeUntil = input.until;
    if (input.busyExtraMinutes !== undefined) {
      store.accept = {
        ...(store.accept ?? acceptSettingsFromRow({})),
        busyExtraMinutes: input.busyExtraMinutes,
      };
    }
    const detail = await this.findStore(store.id);
    if (!detail) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    return detail;
  }

  async updateStoreProfile(
    input: UpdateStoreProfileInput,
  ): Promise<StoreDetail> {
    const store = this.stores.find((entry) => entry.ownerId === input.ownerId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    if (input.name !== undefined) store.name = input.name;
    if (input.logoUrl !== undefined) store.logoUrl = input.logoUrl;
    if (input.coverUrl !== undefined) store.coverUrl = input.coverUrl;
    if (input.description !== undefined) store.description = input.description;
    if (input.category !== undefined) store.category = input.category;
    if (input.minOrderVnd !== undefined) store.minOrderVnd = input.minOrderVnd;
    const detail = await this.findStore(store.id);
    if (!detail) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    return detail;
  }

  async findStoreLogoUrl(storeId: string): Promise<string | null> {
    return this.stores.find((entry) => entry.id === storeId)?.logoUrl ?? null;
  }

  async findStoreCoverUrl(storeId: string): Promise<string | null> {
    return this.stores.find((entry) => entry.id === storeId)?.coverUrl ?? null;
  }

  async updateStoreLocation(
    input: UpdateStoreLocationInput,
  ): Promise<StoreDetail> {
    const store = this.stores.find((entry) => entry.ownerId === input.ownerId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    store.lat = input.lat;
    store.lng = input.lng;
    if (input.addressLabel !== undefined) {
      store.addressLabel = input.addressLabel?.trim() || null;
    }
    const detail = await this.findStore(store.id);
    if (!detail) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    return detail;
  }

  /** Test helper: create a store with initial items for a non-fixture merchant. */
  async createStore(
    ownerId: string,
    name: string,
    items: CatalogItemInput[],
  ): Promise<StoreDetail> {
    const store = await this.ensureOwnedStore(ownerId, name);
    for (const item of items) {
      await this.createItem({
        ownerId,
        name: item.name,
        priceVnd: item.priceVnd,
      });
    }
    const refreshed = await this.findStore(store.id);
    if (!refreshed) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    return refreshed;
  }

  async createItem(input: CreateCatalogItemInput): Promise<StoreItemView> {
    const store = this.stores.find((entry) => entry.ownerId === input.ownerId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const available = input.available ?? true;
    const stored: StoredItem = {
      id: randomUUID(),
      storeId: store.id,
      name: input.name,
      priceVnd: input.priceVnd,
      originalPriceVnd: input.originalPriceVnd ?? null,
      available,
      moderationStatus: input.moderationStatus ?? 'PENDING',
      createdAt: this.nextItemCreatedAt(),
      description: input.description ?? null,
      prepMinutes: input.prepMinutes ?? null,
      imageUrl: input.imageUrl ?? null,
      imageUrls: input.imageUrl ? [input.imageUrl] : [],
      soldCount: 0,
      menuCategoryId: input.menuCategoryId ?? null,
      optionGroups: [],
    };
    this.items.push(stored);
    return memoryItemView(stored);
  }

  async updateItem(input: UpdateCatalogItemInput): Promise<StoreItemView> {
    const item = this.requireOwnedItem(input.ownerId, input.itemId);
    if (input.name !== undefined) item.name = input.name;
    if (input.priceVnd !== undefined) item.priceVnd = input.priceVnd;
    if (input.originalPriceVnd !== undefined)
      item.originalPriceVnd = input.originalPriceVnd;
    item.originalPriceVnd = shownOriginalPrice(
      item.priceVnd,
      item.originalPriceVnd,
    );
    if (input.available !== undefined) item.available = input.available;
    if (input.description !== undefined) item.description = input.description;
    if (input.prepMinutes !== undefined) item.prepMinutes = input.prepMinutes;
    if (input.imageUrl !== undefined) item.imageUrl = input.imageUrl;
    if (input.imageUrls !== undefined) {
      item.imageUrls = input.imageUrls;
      item.imageUrl = input.imageUrls[0] ?? null;
    } else if (input.imageUrl !== undefined) {
      item.imageUrls = input.imageUrl ? [input.imageUrl] : [];
    }
    if (input.menuCategoryId !== undefined)
      item.menuCategoryId = input.menuCategoryId;
    return memoryItemView(item);
  }

  async findItemImageUrls(itemId: string): Promise<string[]> {
    const item = this.items.find((entry) => entry.id === itemId);
    if (!item) return [];
    if (item.imageUrls?.length) return [...item.imageUrls];
    return item.imageUrl ? [item.imageUrl] : [];
  }

  async findItemImageUrl(itemId: string): Promise<string | null> {
    const item = this.items.find((entry) => entry.id === itemId);
    return item?.imageUrl ?? null;
  }

  private menuCategories = new Map<string, MenuCategoryView[]>();

  async listMenuCategories(ownerId: string): Promise<MenuCategoryView[]> {
    const store = this.stores.find((e) => e.ownerId === ownerId);
    if (!store) return [];
    return [...(this.menuCategories.get(store.id) ?? [])];
  }

  async listFeaturedItems(
    storeIds: string[],
  ): Promise<Map<string, StoreFeaturedItem[]>> {
    const byStore = new Map<string, StoreFeaturedItem[]>();
    for (const storeId of new Set(storeIds)) {
      const rows = this.items
        .filter(
          (item) =>
            item.storeId === storeId &&
            item.available &&
            item.moderationStatus === 'APPROVED',
        )
        .map((item) => ({
          id: item.id,
          name: item.name,
          priceVnd: item.priceVnd,
          originalPriceVnd: shownOriginalPrice(
            item.priceVnd,
            item.originalPriceVnd,
          ),
          imageUrl: item.imageUrl ?? null,
          soldCount: item.soldCount ?? 0,
          addedAt: (item.createdAt ?? this.seededAt).toISOString(),
        }));
      const picked = pickFeaturedItems(rows);
      if (picked.length > 0) byStore.set(storeId, picked);
    }
    return byStore;
  }

  async listStoreMenuSections(
    storeId: string,
    approvedOnly = true,
  ): Promise<StoreMenuSection[]> {
    const used = new Set(
      this.items
        .filter(
          (e) =>
            e.storeId === storeId &&
            (!approvedOnly || e.moderationStatus === 'APPROVED'),
        )
        .map((e) => e.menuCategoryId ?? null),
    );
    return (this.menuCategories.get(storeId) ?? [])
      .filter((row) => used.has(row.id))
      .sort((a, b) => a.position - b.position || a.name.localeCompare(b.name))
      .map((row) => ({ id: row.id, name: row.name }));
  }

  async createMenuCategory(input: {
    ownerId: string;
    name: string;
    description?: string | null;
  }): Promise<MenuCategoryView> {
    const store = this.stores.find((e) => e.ownerId === input.ownerId);
    if (!store) throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    const list = this.menuCategories.get(store.id) ?? [];
    const row: MenuCategoryView = {
      id: randomUUID(),
      name: input.name.trim(),
      description: input.description?.trim() || null,
      position: list.length,
      itemCount: 0,
    };
    list.push(row);
    this.menuCategories.set(store.id, list);
    return { ...row };
  }

  async updateMenuCategory(input: {
    ownerId: string;
    categoryId: string;
    name?: string;
    description?: string | null;
  }): Promise<MenuCategoryView> {
    const store = this.stores.find((e) => e.ownerId === input.ownerId);
    if (!store) throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    const list = this.menuCategories.get(store.id) ?? [];
    const row = list.find((c) => c.id === input.categoryId);
    if (!row) throw new FoodRuleError('FOOD_CATEGORY_NOT_FOUND');
    if (input.name !== undefined) row.name = input.name.trim();
    if (input.description !== undefined)
      row.description = input.description?.trim() || null;
    return { ...row };
  }

  async deleteMenuCategory(
    ownerId: string,
    categoryId: string,
  ): Promise<{ deleted: true }> {
    const store = this.stores.find((e) => e.ownerId === ownerId);
    if (!store) throw new FoodRuleError('FOOD_CATEGORY_NOT_FOUND');
    const list = this.menuCategories.get(store.id) ?? [];
    const next = list.filter((c) => c.id !== categoryId);
    if (next.length === list.length)
      throw new FoodRuleError('FOOD_CATEGORY_NOT_FOUND');
    this.menuCategories.set(store.id, next);
    for (const item of this.items) {
      if (item.menuCategoryId === categoryId) item.menuCategoryId = null;
    }
    return { deleted: true };
  }

  async reorderMenuCategories(
    ownerId: string,
    orderedIds: string[],
  ): Promise<MenuCategoryView[]> {
    const store = this.stores.find((e) => e.ownerId === ownerId);
    if (!store) throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    const list = this.menuCategories.get(store.id) ?? [];
    if (
      orderedIds.length !== list.length ||
      orderedIds.some((id) => !list.some((c) => c.id === id))
    ) {
      throw new FoodRuleError('FOOD_CATEGORY_REORDER_INVALID');
    }
    const byId = new Map(list.map((c) => [c.id, c]));
    const next = orderedIds.map((id, position) => {
      const row = byId.get(id)!;
      row.position = position;
      return row;
    });
    this.menuCategories.set(store.id, next);
    return next.map((c) => ({ ...c }));
  }

  async listMerchantHistory(filter: MerchantHistoryFilter) {
    const store = this.stores.find((e) => e.ownerId === filter.ownerId);
    if (!store) {
      return {
        items: [],
        page: filter.page,
        limit: filter.limit,
        total: 0,
        deliveredCount: 0,
        deliveredRevenueVnd: 0,
      };
    }
    const tab = (filter.tab ?? 'ALL').toUpperCase();
    let rows = this.orders.filter(
      (o) =>
        o.storeId === store.id &&
        ['DELIVERED', 'CANCELLED', 'FAILED'].includes(o.status) &&
        (tab === 'ALL' || o.status === tab),
    );
    const q = filter.q?.trim().toLowerCase();
    if (q) {
      rows = rows.filter((o) => o.id.toLowerCase().includes(q));
    }
    rows = [...rows].sort(
      (a, b) =>
        (b.updatedAt?.getTime?.() ?? 0) - (a.updatedAt?.getTime?.() ?? 0),
    );
    const delivered = rows.filter((o) => o.status === 'DELIVERED');
    const pageRows = rows.slice(
      (filter.page - 1) * filter.limit,
      filter.page * filter.limit,
    );
    return {
      items: pageRows.map((o) => ({
        id: o.id,
        status: o.status,
        subtotalVnd: o.subtotalVnd,
        totalVnd: o.totalVnd,
        createdAt: o.createdAt,
        finishedAt: o.updatedAt ?? o.createdAt,
        customerName: null,
        lineSummary: '',
      })),
      page: filter.page,
      limit: filter.limit,
      total: rows.length,
      deliveredCount: delivered.length,
      deliveredRevenueVnd: delivered.reduce((sum, o) => sum + o.subtotalVnd, 0),
    };
  }

  async replaceItemOptions(
    input: ReplaceItemOptionsInput,
  ): Promise<StoreItemView> {
    const item = this.requireOwnedItem(input.ownerId, input.itemId);
    item.optionGroups = normalizeOptionGroups(
      input.groups,
      item.optionGroups,
      randomUUID,
    );
    return memoryItemView(item);
  }

  async setItemAvailability(
    input: SetItemAvailabilityInput,
  ): Promise<StoreItemView> {
    const item = this.requireOwnedItem(input.ownerId, input.itemId);
    // FOOD-001: availability never changes moderation; only APPROVED items can go on sale.
    if (input.available && item.moderationStatus !== 'APPROVED') {
      throw new FoodRuleError('FOOD_ITEM_NOT_APPROVED');
    }
    item.available = input.available;
    return memoryItemView(item);
  }

  async setCatalogModeration(
    itemId: string,
    decision: 'APPROVED' | 'REJECTED',
  ): Promise<{
    id: string;
    available: boolean;
    moderationStatus: string;
  } | null> {
    const item = this.items.find((entry) => entry.id === itemId);
    if (!item) {
      return null;
    }
    item.moderationStatus = decision;
    item.available = decision === 'APPROVED';
    return {
      id: item.id,
      available: item.available,
      moderationStatus: item.moderationStatus,
    };
  }

  async listOrdersPage(
    page: number,
    limit: number,
    filter?: {
      status?: string;
      statuses?: string[];
      q?: string;
      store?: string;
      payment?: string;
      zone?: string;
      window?: OpsDateWindow;
    },
  ): Promise<OpsFoodOrderPage> {
    let sorted = [...this.orders]
      .filter((o) => inDateWindow(o.createdAt, filter?.window))
      .sort(byCreatedAtDesc);
    if (filter?.statuses && filter.statuses.length > 0) {
      const allowed = new Set(
        filter.statuses.map((s) => s.trim().toUpperCase()).filter(Boolean),
      );
      sorted = sorted.filter((o) => allowed.has(o.status.toUpperCase()));
    } else if (filter?.status && filter.status !== 'ALL') {
      const targetStatus = filter.status.toUpperCase();
      sorted = sorted.filter((o) => o.status.toUpperCase() === targetStatus);
    }
    if (filter?.store && filter.store !== 'ALL') {
      const store = filter.store.toLowerCase();
      sorted = sorted.filter((o) => {
        const storeName = this.stores
          .find((s) => s.id === o.storeId)
          ?.name?.toLowerCase();
        return (
          o.storeId.toLowerCase().includes(store) ||
          (storeName && storeName.includes(store))
        );
      });
    }
    if (filter?.zone && filter.zone !== 'ALL') {
      const code = normalizeRegionFilter(filter.zone);
      if (code) {
        const label =
          getServiceRegion(code)?.label.toLowerCase() ?? code.toLowerCase();
        sorted = sorted.filter((o) =>
          o.dropoff.label.toLowerCase().includes(label),
        );
      }
    }
    if (filter?.q && filter.q.trim()) {
      const q = filter.q.trim().toLowerCase();
      sorted = sorted.filter((o) => {
        return (
          o.id.toLowerCase().includes(q) ||
          o.customerId.toLowerCase().includes(q) ||
          o.storeId.toLowerCase().includes(q) ||
          o.dropoff.label.toLowerCase().includes(q) ||
          o.lines.some((line) => line.name.toLowerCase().includes(q))
        );
      });
    }
    const total = sorted.length;
    const start = (page - 1) * limit;
    return {
      items: sorted.slice(start, start + limit).map(copyOrder),
      total,
    };
  }

  async listOrdersForCustomer(
    customerId: string,
    page: number,
    limit: number,
  ): Promise<OpsFoodOrderPage> {
    const sorted = this.orders
      .filter((order) => order.customerId === customerId)
      .sort(byCreatedAtDesc);
    const total = sorted.length;
    const start = (page - 1) * limit;
    return {
      items: sorted.slice(start, start + limit).map(copyOrder),
      total,
    };
  }

  async countFinishedForDrivers(
    driverIds: readonly string[],
  ): Promise<Map<string, DriverJobCounts>> {
    const wanted = new Set(driverIds);
    const statuses: readonly string[] = DRIVER_HISTORY_FOOD_STATUSES;
    const counts = new Map<string, DriverJobCounts>();
    for (const order of this.orders) {
      const driverId = order.assignedDriverId;
      if (
        !driverId ||
        !wanted.has(driverId) ||
        !statuses.includes(order.status) ||
        !cancellationCountsAgainstDriver(order.status, order.cancelledBy)
      ) {
        continue;
      }
      const current = counts.get(driverId) ?? { completed: 0, finished: 0 };
      current.finished += 1;
      if (order.status === 'DELIVERED') {
        current.completed += 1;
      }
      counts.set(driverId, current);
    }
    return counts;
  }

  async listFinishedForDriver(
    driverId: string,
    window: FoodDriverHistoryWindow,
  ): Promise<FoodOrderView[]> {
    const statuses: readonly string[] = DRIVER_HISTORY_FOOD_STATUSES;
    return this.orders
      .filter(
        (order) =>
          order.assignedDriverId === driverId &&
          statuses.includes(order.status) &&
          (!window.before ||
            order.updatedAt.getTime() <= window.before.getTime()) &&
          (!window.since ||
            order.updatedAt.getTime() >= window.since.getTime()),
      )
      .sort(
        (left, right) =>
          right.updatedAt.getTime() - left.updatedAt.getTime() ||
          right.id.localeCompare(left.id),
      )
      .slice(0, window.limit)
      .map(copyOrder);
  }

  async accept(orderId: string, ownerId: string): Promise<FoodOrderView> {
    const order = this.requireOwned(orderId, ownerId);
    if (order.status !== 'PLACED') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.status = 'PREPARING';
    order.acceptedAt = new Date();
    touchOrder(order);
    return copyOrder(order);
  }

  async reject(
    orderId: string,
    ownerId: string,
    reason: FoodCancelReason,
  ): Promise<FoodOrderView> {
    const order = this.requireOwned(orderId, ownerId);
    if (order.status !== 'PLACED') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.status = 'CANCELLED';
    order.cancelReason = { ...reason };
    order.cancelledBy = 'MERCHANT';
    await this.vouchers?.release({
      entityType: 'FOOD_ORDER',
      entityId: order.id,
    });
    touchOrder(order);
    return copyOrder(order);
  }

  async markReady(orderId: string, ownerId: string): Promise<FoodOrderView> {
    const order = this.requireOwned(orderId, ownerId);
    if (order.status !== 'PREPARING') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    if (
      this.changes.some(
        (change) => change.orderId === orderId && change.status === 'PENDING',
      )
    ) {
      throw new FoodRuleError('FOOD_CHANGE_PENDING');
    }
    // A driver claimed early → straight to ASSIGNED; otherwise open for claims.
    order.status = order.assignedDriverId ? 'ASSIGNED' : 'READY';
    order.readyAt = new Date();
    touchOrder(order);
    return copyOrder(order);
  }

  readonly driverCancellations: MemoryDriverJobCancellation[] = [];

  async claim(
    orderId: string,
    driverId: string,
    maxConcurrentJobs = 1,
    early?: FoodEarlyClaim,
    fare?: FoodClaimFare,
  ): Promise<FoodOrderView> {
    const order = this.orders.find((entry) => entry.id === orderId);
    const offer = fare
      ? this.deliveryOffers.find(
          (entry) =>
            entry.id === fare.offerId &&
            entry.orderId === orderId &&
            entry.driverId === driverId,
        )
      : undefined;
    if (fare) {
      if (!order || order.customerId !== fare.customerId) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      if (!offer || offer.status !== 'PENDING') {
        throw new FoodRuleError('FOOD_OFFER_NOT_FOUND');
      }
      if (offer.expiresAt.getTime() <= fare.now.getTime()) {
        throw new FoodRuleError('FOOD_OFFER_EXPIRED');
      }
    }
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (order.customerId === driverId) {
      throw new FoodRuleError('FOOD_SELF_CLAIM');
    }
    if (order.status === 'ASSIGNED' || order.assignedDriverId !== null) {
      throw new FoodRuleError('FOOD_ALREADY_ASSIGNED');
    }
    const isEarly = order.status === 'PREPARING';
    if (order.status !== 'READY' && !isEarly) {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    if (isEarly) {
      const opensAt = early
        ? earlyClaimOpensAt(order, early.leadMinutes)
        : null;
      if (!early || !opensAt || opensAt.getTime() > early.now.getTime()) {
        throw new FoodRuleError('FOOD_NOT_YET_CLAIMABLE');
      }
    }
    const active = this.orders.filter(
      (entry) =>
        entry.assignedDriverId === driverId &&
        (entry.status === 'PREPARING' ||
          entry.status === 'ASSIGNED' ||
          entry.status === 'PICKED_UP'),
    ).length;
    if (active >= maxConcurrentJobs) {
      throw new FoodRuleError('DRIVER_AT_CAPACITY');
    }
    if (!isEarly) {
      order.status = 'ASSIGNED';
    }
    order.assignedDriverId = driverId;
    if (offer) {
      order.deliveryFareVnd = offer.amountVnd;
      order.totalVnd = Math.max(
        0,
        order.subtotalVnd + offer.amountVnd - order.discountVnd,
      );
    }
    order.deliveryFareAgreedAt = fare?.now ?? new Date();
    const stamp = new Date();
    for (const entry of this.deliveryOffers) {
      if (entry.orderId === orderId && entry.status === 'PENDING') {
        entry.status = entry.id === offer?.id ? 'SELECTED' : 'LOST';
        entry.updatedAt = stamp;
      }
    }
    touchOrder(order);
    return copyOrder(order);
  }

  async submitDeliveryOffer(
    input: SubmitFoodDeliveryOfferInput,
  ): Promise<FoodDeliveryOfferView> {
    const order = this.orders.find((entry) => entry.id === input.orderId);
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (order.customerId === input.driverId) {
      throw new FoodRuleError('FOOD_SELF_CLAIM');
    }
    if (order.assignedDriverId !== null || order.status === 'ASSIGNED') {
      throw new FoodRuleError('FOOD_ALREADY_ASSIGNED');
    }
    if (order.status === 'PREPARING') {
      const opensAt = earlyClaimOpensAt(order, input.early.leadMinutes);
      if (!opensAt || opensAt.getTime() > input.early.now.getTime()) {
        throw new FoodRuleError('FOOD_NOT_YET_CLAIMABLE');
      }
    } else if (order.status !== 'READY') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    const ceiling = counterCeilingVnd(
      order.deliveryFareVnd,
      input.counterMaxPercent,
      input.maxFareVnd,
    );
    if (
      input.amountVnd <= order.deliveryFareVnd ||
      input.amountVnd > ceiling
    ) {
      throw new FoodRuleError('FOOD_OFFER_AMOUNT_INVALID');
    }
    const now = input.early.now;
    const existing = this.deliveryOffers.find(
      (entry) =>
        entry.orderId === input.orderId && entry.driverId === input.driverId,
    );
    if (existing) {
      if (existing.status === 'SELECTED' || existing.status === 'LOST') {
        throw new FoodRuleError('FOOD_STATUS_CONFLICT');
      }
      if (existing.editCount >= input.maxEdits) {
        throw new FoodRuleError('FOOD_OFFER_EDIT_LIMIT');
      }
      existing.amountVnd = input.amountVnd;
      existing.status = 'PENDING';
      existing.expiresAt = new Date(input.expiresAt);
      existing.editCount += 1;
      existing.updatedAt = now;
      return { ...existing };
    }
    const created: FoodDeliveryOfferView = {
      id: randomUUID(),
      orderId: input.orderId,
      driverId: input.driverId,
      amountVnd: input.amountVnd,
      status: 'PENDING',
      expiresAt: new Date(input.expiresAt),
      editCount: 0,
      createdAt: now,
      updatedAt: now,
    };
    this.deliveryOffers.push(created);
    return { ...created };
  }

  async withdrawDeliveryOffer(
    orderId: string,
    driverId: string,
  ): Promise<FoodDeliveryOfferView> {
    const offer = this.deliveryOffers.find(
      (entry) => entry.orderId === orderId && entry.driverId === driverId,
    );
    if (!offer || offer.status !== 'PENDING') {
      throw new FoodRuleError('FOOD_OFFER_NOT_FOUND');
    }
    offer.status = 'WITHDRAWN';
    offer.updatedAt = new Date();
    return { ...offer };
  }

  async listDeliveryOffers(orderId: string): Promise<FoodDeliveryOfferView[]> {
    return this.deliveryOffers
      .filter((entry) => entry.orderId === orderId)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .map((entry) => ({ ...entry }));
  }

  async raiseDeliveryFare(
    input: RaiseFoodDeliveryFareInput,
  ): Promise<FoodOrderView> {
    const order = this.orders.find((entry) => entry.id === input.orderId);
    if (!order || order.customerId !== input.customerId) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (
      order.assignedDriverId !== null ||
      !['PLACED', 'PREPARING', 'READY'].includes(order.status)
    ) {
      throw new FoodRuleError('FOOD_FARE_LOCKED');
    }
    if ((order.deliveryFareRaiseCount ?? 0) >= input.maxRaises) {
      throw new FoodRuleError('FOOD_FARE_RAISE_LIMIT');
    }
    if (input.amountVnd <= order.deliveryFareVnd) {
      throw new FoodRuleError('FOOD_OFFER_AMOUNT_INVALID');
    }
    order.deliveryFareVnd = input.amountVnd;
    order.totalVnd = Math.max(
      0,
      order.subtotalVnd + input.amountVnd - order.discountVnd,
    );
    order.deliveryFareRaiseCount = (order.deliveryFareRaiseCount ?? 0) + 1;
    touchOrder(order);
    return copyOrder(order);
  }

  async release(
    orderId: string,
    driverId: string,
    reasonCode: string,
  ): Promise<FoodOrderView> {
    const order = this.requireAssignedDriver(orderId, driverId);
    if (order.status !== 'ASSIGNED' && order.status !== 'PREPARING') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    const fromStatus = order.status;
    order.status = order.status === 'ASSIGNED' ? 'READY' : 'PREPARING';
    order.assignedDriverId = null;
    order.deliveryFareAgreedAt = null;
    this.driverCancellations.push({
      orderId,
      driverId,
      reasonCode,
      fromStatus,
      createdAt: new Date(),
    });
    touchOrder(order);
    return copyOrder(order);
  }

  async timeoutDue(
    now: Date,
    policy: FoodTimeoutPolicy,
    limit = 100,
  ): Promise<FoodTimedOut[]> {
    const out: FoodTimedOut[] = [];
    const placedCutoff = now.getTime() - policy.merchantAcceptMinutes * 60_000;
    const readyCutoff = now.getTime() - policy.unclaimedReadyMinutes * 60_000;
    for (const order of [...this.orders].sort(byCreatedAt)) {
      if (out.length >= limit) break;
      let reason: FoodSystemCancelReason | null = null;
      if (
        order.status === 'PLACED' &&
        order.createdAt.getTime() <= placedCutoff
      ) {
        reason = 'MERCHANT_TIMEOUT';
      } else if (
        order.status === 'READY' &&
        order.assignedDriverId === null &&
        (order.readyAt ?? order.updatedAt).getTime() <= readyCutoff
      ) {
        reason = 'NO_DRIVER';
      }
      if (!reason) continue;
      order.status = 'CANCELLED';
      order.cancelledBy = 'SYSTEM';
      order.cancelReason = { code: reason, note: null };
      await this.vouchers?.release({
        entityType: 'FOOD_ORDER',
        entityId: order.id,
      });
      order.updatedAt = now;
      out.push({ orderId: order.id, reason });
    }
    return out;
  }

  async pickup(
    orderId: string,
    driverId: string,
    snapshot?: { merchantCashVnd: number; at: Date },
  ): Promise<FoodOrderView> {
    const order = this.requireAssignedDriver(orderId, driverId);
    if (order.status !== 'ASSIGNED') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.pickedUpAt = snapshot?.at ?? new Date();
    order.merchantCashVnd = snapshot?.merchantCashVnd ?? null;
    return this.assignedDriverTransition(
      orderId,
      driverId,
      'ASSIGNED',
      'PICKED_UP',
    );
  }

  async snapshotCommissionWithin(
    _tx: TxHandle,
    orderId: string,
    input: { commissionBps: number; commissionVnd: number },
  ): Promise<void> {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (order) {
      order.merchantCommissionBps = input.commissionBps;
      order.merchantCommissionVnd = input.commissionVnd;
    }
  }

  async deliver(
    orderId: string,
    driverId: string,
    onDelivered?: CompletionHook<FoodOrderView>,
  ): Promise<FoodOrderView> {
    const order = this.requireAssignedDriver(orderId, driverId);
    if (order.status !== 'PICKED_UP') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    const delivered = { ...copyOrder(order), status: 'DELIVERED' as const };
    // Memory mode: run the hook before mutating so a failure leaves the order PICKED_UP.
    await onDelivered?.(null, delivered);
    order.status = 'DELIVERED';
    touchOrder(order);
    return copyOrder(order);
  }

  async fail(
    orderId: string,
    driverId: string,
    input: FoodFailInput,
    onFailed?: CompletionHook<FoodOrderView>,
  ): Promise<FoodOrderView> {
    const order = this.requireAssignedDriver(orderId, driverId);
    // Before pickup the driver releases instead (the food is still at the store).
    if (order.status !== 'PICKED_UP') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    assertFailWaitOver(order.pickedUpAt, input);
    const failed: FoodOrderView = {
      ...copyOrder(order),
      status: 'FAILED',
      failReason: { code: input.reasonCode, note: input.note },
    };
    await onFailed?.(null, failed);
    order.status = 'FAILED';
    order.failReason = { code: input.reasonCode, note: input.note };
    // Confirmed (DEC-PROD-012): a failed delivery gives the voucher use back.
    await this.vouchers?.release({
      entityType: 'FOOD_ORDER',
      entityId: order.id,
    });
    touchOrder(order);
    return copyOrder(order);
  }

  readonly changes: FoodOrderChangeView[] = [];

  async proposeChange(
    input: ProposeFoodOrderChangeInput,
  ): Promise<FoodOrderChangeResult> {
    const order = this.requireOwned(input.orderId, input.ownerId);
    if (!FOOD_CHANGE_EDITABLE_STATUSES.includes(order.status)) {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    if (
      this.changes.some(
        (change) => change.orderId === order.id && change.status === 'PENDING',
      )
    ) {
      throw new FoodRuleError('FOOD_CHANGE_PENDING');
    }
    const plan = planFoodOrderChange(order, input.lines);
    const change: FoodOrderChangeView = {
      id: randomUUID(),
      orderId: order.id,
      status: 'PENDING',
      reasonCode: input.reasonCode,
      note: input.note,
      ...plan,
      expiresAt: input.expiresAt,
      respondedAt: null,
      createdAt: new Date(),
    };
    this.changes.push(change);
    touchOrder(order);
    return { order: copyOrder(order), change: copyChange(change) };
  }

  async latestChange(orderId: string): Promise<FoodOrderChangeView | null> {
    const rows = this.changes.filter((change) => change.orderId === orderId);
    const latest = rows.at(-1);
    return latest ? copyChange(latest) : null;
  }

  async respondChange(
    orderId: string,
    customerId: string,
    changeId: string,
    accept: boolean,
    now: Date,
  ): Promise<FoodOrderChangeResult> {
    const order = this.orders.find(
      (entry) => entry.id === orderId && entry.customerId === customerId,
    );
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    const change = this.changes.find(
      (entry) => entry.id === changeId && entry.orderId === orderId,
    );
    if (!change) {
      throw new FoodRuleError('FOOD_CHANGE_NOT_FOUND');
    }
    if (
      change.status !== 'PENDING' ||
      !FOOD_CHANGE_EDITABLE_STATUSES.includes(order.status)
    ) {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    if (change.expiresAt.getTime() <= now.getTime()) {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    change.respondedAt = now;
    if (accept) {
      change.status = 'ACCEPTED';
      order.lines = applyFoodOrderChangeLines(order.lines, change.lines);
      order.subtotalVnd = change.newSubtotalVnd;
      order.discountVnd = change.newDiscountVnd;
      order.totalVnd = change.newTotalVnd;
    } else {
      change.status = 'REJECTED';
      order.status = 'CANCELLED';
      order.cancelledBy = 'CUSTOMER';
      order.cancelReason = { code: 'CHANGE_REJECTED', note: null };
      await this.vouchers?.release({
        entityType: 'FOOD_ORDER',
        entityId: order.id,
      });
    }
    touchOrder(order);
    return { order: copyOrder(order), change: copyChange(change) };
  }

  async expireChanges(now: Date, limit = 100): Promise<string[]> {
    const out: string[] = [];
    for (const change of this.changes) {
      if (out.length >= limit) break;
      if (
        change.status !== 'PENDING' ||
        change.expiresAt.getTime() > now.getTime()
      )
        continue;
      change.status = 'EXPIRED';
      change.respondedAt = now;
      const order = this.orders.find((entry) => entry.id === change.orderId);
      if (!order || !FOOD_CHANGE_EDITABLE_STATUSES.includes(order.status))
        continue;
      order.status = 'CANCELLED';
      order.cancelledBy = 'SYSTEM';
      order.cancelReason = { code: 'CHANGE_EXPIRED', note: null };
      await this.vouchers?.release({
        entityType: 'FOOD_ORDER',
        entityId: order.id,
      });
      order.updatedAt = now;
      out.push(order.id);
    }
    return out;
  }

  async cancel(orderId: string, customerId: string): Promise<FoodOrderView> {
    const order = this.orders.find(
      (entry) => entry.id === orderId && entry.customerId === customerId,
    );
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (order.status !== 'PLACED') {
      throw new FoodRuleError('FOOD_NOT_CANCELLABLE');
    }
    order.status = 'CANCELLED';
    order.cancelledBy = 'CUSTOMER';
    await this.vouchers?.release({
      entityType: 'FOOD_ORDER',
      entityId: order.id,
    });
    touchOrder(order);
    return copyOrder(order);
  }

  async opsCancel(
    orderId: string,
    _actorUserId: string,
    _reason: string,
  ): Promise<OpsFoodInterveneResult> {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (
      order.status === 'DELIVERED' ||
      order.status === 'FAILED' ||
      order.status === 'CANCELLED'
    ) {
      throw new FoodRuleError('FOOD_NOT_CANCELLABLE');
    }
    order.status = 'CANCELLED';
    order.cancelledBy = 'OPS';
    await this.vouchers?.release({
      entityType: 'FOOD_ORDER',
      entityId: order.id,
    });
    touchOrder(order);
    return {
      order: copyOrder(order),
      auditId: `memory-audit-${order.id}-cancel`,
    };
  }

  async opsReassign(
    orderId: string,
    _actorUserId: string,
    _reason: string,
  ): Promise<OpsFoodInterveneResult> {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (order.status !== 'ASSIGNED') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.status = 'READY';
    order.assignedDriverId = null;
    touchOrder(order);
    return {
      order: copyOrder(order),
      auditId: `memory-audit-${order.id}-reassign`,
    };
  }

  private assignedDriverTransition(
    orderId: string,
    driverId: string,
    from: FoodOrderStatusName,
    to: FoodOrderStatusName,
  ): FoodOrderView {
    const order = this.requireAssignedDriver(orderId, driverId);
    if (order.status !== from) {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.status = to;
    touchOrder(order);
    return copyOrder(order);
  }

  private requireAssignedDriver(
    orderId: string,
    driverId: string,
  ): StoredOrder {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (order.assignedDriverId !== driverId) {
      throw new FoodRuleError('FOOD_NOT_ASSIGNED_DRIVER');
    }
    return order;
  }

  private requireOwned(orderId: string, ownerId: string): StoredOrder {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (!order || order.ownerId !== ownerId) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    return order;
  }

  private toOpsStoreSummary(store: StoredStore): OpsStoreSummary {
    return {
      ...toStoreListItem(store),
      ...effectiveServiceMode(store.serviceMode, store.serviceModeUntil),
      ...memoryAvailability(store),
      ...memoryAccept(store),
      createdAt: new Date(store.createdAt),
      itemCount: this.items.filter((item) => item.storeId === store.id).length,
    };
  }

  private requireOwnedItem(ownerId: string, itemId: string): StoredItem {
    const item = this.items.find((entry) => entry.id === itemId);
    if (!item) {
      throw new FoodRuleError('FOOD_ITEM_NOT_FOUND');
    }
    const store = this.stores.find((entry) => entry.id === item.storeId);
    if (!store || store.ownerId !== ownerId) {
      throw new FoodRuleError('FOOD_NOT_STORE_OWNER');
    }
    return item;
  }

  private snapshotLines(
    storeId: string,
    requested: PlaceFoodLineInput[],
    requireApprovedItems = true,
  ): FoodLineView[] {
    return snapshotFoodLines(
      this.items
        .filter((entry) => entry.storeId === storeId)
        .map((entry) => ({ ...memoryItemView(entry), moderationStatus: entry.moderationStatus })),
      requested,
      requireApprovedItems,
    );
  }
}

function coverImageForStore(
  items: Array<{
    storeId: string;
    available: boolean;
    imageUrl: string | null;
  }>,
  storeId: string,
): string | null {
  for (const item of items) {
    if (item.storeId === storeId && item.available && item.imageUrl) {
      return item.imageUrl;
    }
  }
  for (const item of items) {
    if (item.storeId === storeId && item.imageUrl) {
      return item.imageUrl;
    }
  }
  return null;
}

function toStoreListItem(store: StoredStore): StoreListItem {
  return {
    id: store.id,
    name: store.name,
    ownerId: store.ownerId,
    lat: store.lat,
    lng: store.lng,
    category: store.category,
    addressLabel: store.addressLabel ?? null,
    logoUrl: store.logoUrl ?? null,
    coverUrl: store.coverUrl ?? null,
    description: store.description ?? null,
    minOrderVnd: store.minOrderVnd ?? 0,
  };
}

function byCreatedAt(
  left: { createdAt: Date; id: string },
  right: { createdAt: Date; id: string },
): number {
  return (
    left.createdAt.getTime() - right.createdAt.getTime() ||
    left.id.localeCompare(right.id)
  );
}

function byCreatedAtDesc(
  left: { createdAt: Date; id: string },
  right: { createdAt: Date; id: string },
): number {
  return (
    right.createdAt.getTime() - left.createdAt.getTime() ||
    left.id.localeCompare(right.id)
  );
}

function memoryItemView(item: StoredItem): StoreItemView {
  return {
    id: item.id,
    name: item.name,
    priceVnd: item.priceVnd,
    originalPriceVnd: shownOriginalPrice(item.priceVnd, item.originalPriceVnd),
    available: item.available,
    addedAt: item.createdAt ? item.createdAt.toISOString() : null,
    moderationStatus: item.moderationStatus,
    description: item.description ?? null,
    prepMinutes: item.prepMinutes ?? null,
    imageUrl: item.imageUrl ?? null,
    imageUrls: item.imageUrls ?? (item.imageUrl ? [item.imageUrl] : []),
    soldCount: item.soldCount ?? 0,
    menuCategoryId: item.menuCategoryId ?? null,
    optionGroups: item.optionGroups.map((group) => ({
      ...group,
      options: group.options.map((option) => ({
        ...option,
        maxQuantity: option.maxQuantity ?? 1,
      })),
    })),
  };
}

/**
 * Shared by both repositories: validates every requested line against the
 * store catalog, prices chosen options server-side and snapshots them. The same
 * dish may appear twice only with a different option choice.
 */
export function snapshotFoodLines(
  catalog: ReadonlyArray<
    Pick<
      StoreItemView,
      'id' | 'name' | 'priceVnd' | 'available' | 'optionGroups' | 'imageUrl'
    > & { moderationStatus: string }
  >,
  requested: PlaceFoodLineInput[],
  requireApprovedItems = true,
): FoodLineView[] {
  const seen = new Set<string>();
  return requested.map((line) => {
    const key = lineKey(line.itemId, line.optionIds);
    if (seen.has(key)) {
      throw new FoodRuleError('FOOD_ITEM_UNAVAILABLE');
    }
    seen.add(key);
    const item = catalog.find((entry) => entry.id === line.itemId);
    if (
      !item ||
      !item.available ||
      (requireApprovedItems && item.moderationStatus !== 'APPROVED')
    ) {
      throw new FoodRuleError('FOOD_ITEM_UNAVAILABLE');
    }
    const priced = priceOptionSelection(
      item.optionGroups,
      line.optionIds ?? [],
    );
    return {
      id: randomUUID(),
      itemId: item.id,
      name: item.name,
      unitPriceVnd: item.priceVnd + priced.deltaVnd,
      quantity: line.quantity,
      imageUrl: item.imageUrl ?? null,
      note: line.note ?? null,
      options: priced.options,
    };
  });
}

function copyChange(change: FoodOrderChangeView): FoodOrderChangeView {
  return {
    ...change,
    lines: change.lines.map((line) => ({ ...line })),
    expiresAt: new Date(change.expiresAt),
    respondedAt: change.respondedAt ? new Date(change.respondedAt) : null,
    createdAt: new Date(change.createdAt),
  };
}

function copyOrder(order: StoredOrder): FoodOrderView {
  return {
    id: order.id,
    customerId: order.customerId,
    storeId: order.storeId,
    storeName: order.storeName ?? null,
    serviceRegionCode: order.serviceRegionCode ?? null,
    ownerId: order.ownerId,
    status: order.status,
    deliveryFareVnd: order.deliveryFareVnd,
    subtotalVnd: order.subtotalVnd,
    discountVnd: order.discountVnd,
    voucherCode: order.voucherCode,
    voucherSponsor: order.voucherSponsor ?? null,
    totalVnd: order.totalVnd,
    dropoff: { ...order.dropoff },
    pickup: order.pickup ? { ...order.pickup } : null,
    assignedDriverId: order.assignedDriverId,
    cancelReason: order.cancelReason ? { ...order.cancelReason } : null,
    cancelledBy: order.cancelledBy ?? null,
    note: order.note ?? null,
    utensils: order.utensils ?? true,
    lines: order.lines.map((line) => ({
      ...line,
      options: line.options.map((option) => ({ ...option })),
    })),
    prepMinutes: order.prepMinutes ?? null,
    estimatedReadyAt: order.estimatedReadyAt
      ? new Date(order.estimatedReadyAt)
      : null,
    pickedUpAt: order.pickedUpAt ? new Date(order.pickedUpAt) : null,
    failReason: order.failReason ? { ...order.failReason } : null,
    merchantCashVnd: order.merchantCashVnd ?? null,
    createdAt: new Date(order.createdAt),
    updatedAt: new Date(order.updatedAt),
    suggestedDeliveryFareVnd:
      order.suggestedDeliveryFareVnd ?? order.deliveryFareVnd,
    deliveryFareAgreedAt: order.deliveryFareAgreedAt
      ? new Date(order.deliveryFareAgreedAt)
      : null,
    deliveryFareRaiseCount: order.deliveryFareRaiseCount ?? 0,
  };
}

/** Statuses in which the kitchen can still edit an order. */
export const FOOD_CHANGE_EDITABLE_STATUSES: readonly FoodOrderStatusName[] = [
  'PLACED',
  'PREPARING',
];

/**
 * Validates a merchant edit and prices it. Only lower quantities / removals
 * (the kitchen cannot add items for the customer); at least one line must remain, otherwise the
 * merchant should reject the order. The voucher discount is capped at the new subtotal.
 */
export function planFoodOrderChange(
  order: Pick<
    FoodOrderView,
    'lines' | 'subtotalVnd' | 'discountVnd' | 'deliveryFareVnd'
  >,
  requested: { lineId: string; toQuantity: number }[],
): Pick<
  FoodOrderChangeView,
  | 'lines'
  | 'oldSubtotalVnd'
  | 'newSubtotalVnd'
  | 'newDiscountVnd'
  | 'newTotalVnd'
> {
  if (requested.length === 0) {
    throw new FoodRuleError('FOOD_CHANGE_INVALID');
  }
  const seen = new Set<string>();
  const lines: FoodOrderChangeLine[] = [];
  for (const entry of requested) {
    const line = order.lines.find((candidate) => candidate.id === entry.lineId);
    if (
      !line ||
      seen.has(entry.lineId) ||
      !Number.isInteger(entry.toQuantity) ||
      entry.toQuantity < 0 ||
      entry.toQuantity >= line.quantity
    ) {
      throw new FoodRuleError('FOOD_CHANGE_INVALID');
    }
    seen.add(entry.lineId);
    lines.push({
      lineId: line.id,
      itemId: line.itemId,
      name: line.name,
      unitPriceVnd: line.unitPriceVnd,
      fromQuantity: line.quantity,
      toQuantity: entry.toQuantity,
    });
  }
  const newSubtotalVnd = order.lines.reduce((sum, line) => {
    const edit = lines.find((entry) => entry.lineId === line.id);
    return sum + line.unitPriceVnd * (edit ? edit.toQuantity : line.quantity);
  }, 0);
  if (newSubtotalVnd <= 0) {
    throw new FoodRuleError('FOOD_CHANGE_INVALID');
  }
  const newDiscountVnd = Math.min(order.discountVnd, newSubtotalVnd);
  return {
    lines,
    oldSubtotalVnd: order.subtotalVnd,
    newSubtotalVnd,
    newDiscountVnd,
    newTotalVnd: Math.max(
      0,
      newSubtotalVnd + order.deliveryFareVnd - newDiscountVnd,
    ),
  };
}

/** Applies accepted change lines to order lines (drops 0-quantity lines). */
export function applyFoodOrderChangeLines(
  lines: FoodLineView[],
  change: FoodOrderChangeLine[],
): FoodLineView[] {
  return lines
    .map((line) => {
      const edit = change.find((entry) => entry.lineId === line.id);
      return edit ? { ...line, quantity: edit.toQuantity } : line;
    })
    .filter((line) => line.quantity > 0);
}

/** "customer unreachable" only after the minimum wait since pickup. */
export function assertFailWaitOver(
  pickedUpAt: Date | null,
  input: FoodFailInput,
): void {
  if (
    input.reasonCode !== 'CUSTOMER_UNREACHABLE' ||
    input.minWaitMinutes <= 0 ||
    !pickedUpAt
  ) {
    return;
  }
  if (
    input.now.getTime() - pickedUpAt.getTime() <
    input.minWaitMinutes * 60_000
  ) {
    throw new FoodRuleError('FOOD_FAIL_TOO_EARLY');
  }
}

export const DEFAULT_CATALOG_MODERATION_ITEMS: OpsCatalogModerationItem[] = [
  {
    id: 'sp-02456',
    code: 'SP-02456',
    name: 'Cà phê muối',
    category: 'Đồ uống',
    store: 'Highlands Coffee',
    price: 39000,
    submittedAt: '10/06 · 10:25',
    status: 'PENDING',
    nameReady: true,
    imageReady: false,
  },
  {
    id: 'sp-02455',
    code: 'SP-02455',
    name: 'Bún bò đặc biệt',
    category: 'Đồ ăn',
    store: 'Bếp Nhà - Đà Nẵng',
    price: 55000,
    submittedAt: '10/06 · 09:48',
    status: 'PENDING',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02454',
    code: 'SP-02454',
    name: 'Pizza hải sản',
    category: 'Đồ ăn',
    store: "Pizza 4P's - Đà Nẵng",
    price: 245000,
    submittedAt: '10/06 · 09:12',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02453',
    code: 'SP-02453',
    name: 'Trà sữa trân châu hoàng gia',
    category: 'Đồ uống',
    store: 'Gong Cha',
    price: 48000,
    submittedAt: '10/06 · 08:35',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02452',
    code: 'SP-02452',
    name: 'Mì Quảng ếch',
    category: 'Đồ ăn',
    store: 'Mì Quảng Bà Mua',
    price: 45000,
    submittedAt: '09/06 · 18:20',
    status: 'REJECTED',
    nameReady: true,
    imageReady: false,
  },
  {
    id: 'sp-02451',
    code: 'SP-02451',
    name: 'Bánh mì pate chả bò',
    category: 'Đồ ăn',
    store: 'Bánh Mì Phượng',
    price: 35000,
    submittedAt: '09/06 · 16:45',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02450',
    code: 'SP-02450',
    name: 'Cơm gà xé Hội An',
    category: 'Đồ ăn',
    store: 'Cơm Gà Bà Buội',
    price: 60000,
    submittedAt: '09/06 · 14:10',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02449',
    code: 'SP-02449',
    name: 'Nước ép dưa hấu bạc hà',
    category: 'Đồ uống',
    store: 'The Alley',
    price: 42000,
    submittedAt: '09/06 · 11:30',
    status: 'PENDING',
    nameReady: true,
    imageReady: false,
  },
  {
    id: 'sp-02448',
    code: 'SP-02448',
    name: 'Gà rán giòn sốt cay',
    category: 'Đồ ăn',
    store: 'Lotteria',
    price: 89000,
    submittedAt: '09/06 · 10:05',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02447',
    code: 'SP-02447',
    name: 'Bánh xèo tôm nhảy',
    category: 'Đồ ăn',
    store: 'Bánh Xèo Cô Ba',
    price: 50000,
    submittedAt: '08/06 · 17:50',
    status: 'REJECTED',
    nameReady: false,
    imageReady: false,
  },
];

export function filterCatalogModerationItems(
  items: OpsCatalogModerationItem[],
  query: {
    page?: number;
    limit?: number;
    q?: string;
    store?: string;
    category?: string;
    status?: string;
    window?: OpsDateWindow;
  },
): OpsCatalogModerationPage {
  const page = Math.max(1, query.page ?? 1);
  const limit = Math.max(1, Math.min(50, query.limit ?? 10));

  let filtered = items.filter((i) =>
    inDateWindow(new Date(i.submittedAt), query.window),
  );
  if (query.status && query.status !== 'ALL') {
    filtered = filtered.filter((i) => i.status === query.status);
  }
  if (query.store && query.store !== 'ALL') {
    const s = query.store.toLowerCase();
    filtered = filtered.filter((i) => i.store.toLowerCase().includes(s));
  }
  if (query.category && query.category !== 'ALL') {
    const c = query.category.toLowerCase();
    filtered = filtered.filter((i) => i.category.toLowerCase().includes(c));
  }
  if (query.q?.trim()) {
    const q = query.q.trim().toLowerCase();
    filtered = filtered.filter(
      (i) =>
        i.code.toLowerCase().includes(q) ||
        i.name.toLowerCase().includes(q) ||
        i.store.toLowerCase().includes(q) ||
        i.category.toLowerCase().includes(q),
    );
  }

  const total = filtered.length;
  const start = (page - 1) * limit;
  return {
    items: filtered.slice(start, start + limit),
    total,
    page,
    limit,
  };
}
