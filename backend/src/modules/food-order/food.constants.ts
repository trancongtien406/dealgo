export const FOOD_REPOSITORY = Symbol('FOOD_REPOSITORY');

export const FIXTURE_MERCHANT_PHONE = '+84901110001';

/** Why a merchant declined a PLACED order (DEC-PROD-021). OTHER requires a note. */
export const FOOD_REJECT_REASONS = [
  'OUT_OF_STOCK',
  'STORE_BUSY',
  'STORE_CLOSING',
  'ITEM_PRICE_CHANGED',
  'OTHER',
] as const;
export type FoodRejectReason = (typeof FOOD_REJECT_REASONS)[number];
export const FOOD_REJECT_NOTE_MAX = 200;

/** System cancellations (worker timeouts). */
export const FOOD_SYSTEM_CANCEL_REASONS = ['MERCHANT_TIMEOUT', 'NO_DRIVER'] as const;
export type FoodSystemCancelReason = (typeof FOOD_SYSTEM_CANCEL_REASONS)[number];
/**
 * Order cancelled because the customer declined the merchant's edit
 * (out of stock / fewer portions) or did not answer in FOOD_ORDER_CHANGE_RESPONSE_MINUTES.
 * No cancellation fee either way (GrabFood / ShopeeFood "món hết, khách xác nhận" flow).
 */
export const FOOD_CHANGE_CANCEL_REASONS = ['CHANGE_REJECTED', 'CHANGE_EXPIRED'] as const;
export type FoodChangeCancelReason = (typeof FOOD_CHANGE_CANCEL_REASONS)[number];
export type FoodCancelReasonCode = FoodRejectReason | FoodSystemCancelReason | FoodChangeCancelReason;

/** Why the merchant edits an order. */
export const FOOD_ORDER_CHANGE_REASONS = ['OUT_OF_STOCK', 'NOT_ENOUGH_PORTIONS', 'OTHER'] as const;
export type FoodOrderChangeReason = (typeof FOOD_ORDER_CHANGE_REASONS)[number];

/** Why a driver hands a claimed food order back before pickup. */
export const FOOD_DRIVER_RELEASE_REASONS = [
  'STORE_TOO_SLOW',
  'STORE_CLOSED',
  'VEHICLE_PROBLEM',
  'SAFETY_CONCERN',
  'OTHER',
] as const;
export type FoodDriverReleaseReason = (typeof FOOD_DRIVER_RELEASE_REASONS)[number];

/**
 * Why a picked-up delivery failed. CUSTOMER_UNREACHABLE needs
 * FOOD_FAIL_MIN_WAIT_MINUTES since pickup (ShopeeFood "đơn rớt" process: call + wait first).
 */
export const FOOD_FAIL_REASONS = [
  'CUSTOMER_UNREACHABLE',
  'CUSTOMER_REFUSED',
  'WRONG_ADDRESS',
  'OTHER',
] as const;
export type FoodFailReason = (typeof FOOD_FAIL_REASONS)[number];
export const FOOD_FAIL_NOTE_MAX = 300;

export const OPEN_FOOD_STATUSES = [
  'PLACED',
  'PREPARING',
  'READY',
  'ASSIGNED',
  'PICKED_UP',
] as const;

export type FoodOrderStatusName =
  | (typeof OPEN_FOOD_STATUSES)[number]
  | 'DELIVERED'
  | 'FAILED'
  | 'CANCELLED';
