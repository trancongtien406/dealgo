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
