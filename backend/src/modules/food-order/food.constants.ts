export const FOOD_REPOSITORY = Symbol('FOOD_REPOSITORY');

export const FIXTURE_MERCHANT_PHONE = '+84901110001';

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
