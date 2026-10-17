/** Mid-lifecycle rides older than this are treated as stuck. */
export const EXCEPTION_STUCK_AFTER_MS = 2 * 60 * 60 * 1000;

/** Terminal CANCELLED/FAILED/EXPIRED within this window appear in the queue. */
export const EXCEPTION_RECENT_MS = 7 * 24 * 60 * 60 * 1000;

export const RIDE_STUCK_STATUSES = [
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
] as const;

export const RIDE_TERMINAL_STATUSES = ['CANCELLED', 'EXPIRED'] as const;

export const FOOD_STUCK_STATUSES = ['PREPARING', 'READY', 'ASSIGNED', 'PICKED_UP'] as const;

export const FOOD_TERMINAL_STATUSES = ['FAILED', 'CANCELLED'] as const;
