import { HttpException } from '@nestjs/common';

export function foodError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ message, errorCode }, status);
}

export const FOOD_RULES = {
  FOOD_ORDER_ALREADY_OPEN: { status: 409, message: 'An open food order already exists' },
  FOOD_ORDER_NOT_FOUND: { status: 404, message: 'Food order not found' },
  FOOD_STORE_NOT_FOUND: { status: 404, message: 'Store not found' },
  FOOD_STORE_PAUSED: { status: 409, message: 'The store is not taking new orders right now' },
  FOOD_STORE_CLOSED: { status: 409, message: 'The store is closed at this time' },
  FOOD_STORE_AT_CAPACITY: {
    status: 409,
    message: 'The store is at its active-order limit; try again shortly',
  },
  FOOD_ITEM_NOT_FOUND: { status: 404, message: 'Catalog item not found' },
  FOOD_ITEM_UNAVAILABLE: { status: 409, message: 'An item is unavailable' },
  FOOD_OPTION_INVALID: {
    status: 409,
    message: 'An item option choice is missing, unavailable or out of bounds',
  },
  FOOD_OPTIONS_INVALID: {
    status: 400,
    message: 'Option groups need 1-20 unique options, 0 ≤ min ≤ max ≤ options, non-negative price deltas',
  },
  FOOD_ALREADY_ASSIGNED: { status: 409, message: 'The order is already assigned' },
  FOOD_NOT_CANCELLABLE: { status: 409, message: 'The order can no longer be cancelled' },
  FOOD_STATUS_CONFLICT: { status: 409, message: 'The order is not in the required status' },
  DRIVER_AT_CAPACITY: {
    status: 409,
    message: 'Driver is at max concurrent jobs',
  },
  FOOD_SELF_CLAIM: { status: 403, message: 'You cannot claim your own order' },
  FOOD_NOT_ASSIGNED_DRIVER: {
    status: 403,
    message: 'Only the assigned driver may perform this action',
  },
  FOOD_NOT_STORE_OWNER: {
    status: 403,
    message: 'Only the store owner may manage this catalog',
  },
  FOOD_CATEGORY_NOT_FOUND: { status: 404, message: 'Menu category not found' },
  FOOD_CATEGORY_REORDER_INVALID: {
    status: 400,
    message: 'Category reorder list must include every category once',
  },
} as const;

export type FoodRuleCode = keyof typeof FOOD_RULES;

export class FoodRuleError extends Error {
  readonly status: number;
  readonly code: FoodRuleCode;

  constructor(code: FoodRuleCode) {
    const rule = FOOD_RULES[code];
    super(rule.message);
    this.name = 'FoodRuleError';
    this.code = code;
    this.status = rule.status;
  }
}
