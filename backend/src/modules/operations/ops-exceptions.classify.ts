import {
  FOOD_STUCK_STATUSES,
  FOOD_TERMINAL_STATUSES,
  RIDE_STUCK_STATUSES,
  RIDE_TERMINAL_STATUSES,
} from './ops-exceptions.constants.js';

export type ExceptionReason = 'stuck' | 'terminal';

export function classifyRideException(
  status: string,
  updatedAt: Date,
  stuckBefore: Date,
  recentAfter: Date,
): ExceptionReason | null {
  if ((RIDE_TERMINAL_STATUSES as readonly string[]).includes(status)) {
    return updatedAt.getTime() >= recentAfter.getTime() ? 'terminal' : null;
  }
  if ((RIDE_STUCK_STATUSES as readonly string[]).includes(status)) {
    return updatedAt.getTime() <= stuckBefore.getTime() ? 'stuck' : null;
  }
  return null;
}

export function classifyFoodException(
  status: string,
  updatedAt: Date,
  stuckBefore: Date,
  recentAfter: Date,
): ExceptionReason | null {
  if ((FOOD_TERMINAL_STATUSES as readonly string[]).includes(status)) {
    return updatedAt.getTime() >= recentAfter.getTime() ? 'terminal' : null;
  }
  if ((FOOD_STUCK_STATUSES as readonly string[]).includes(status)) {
    return updatedAt.getTime() <= stuckBefore.getTime() ? 'stuck' : null;
  }
  return null;
}
