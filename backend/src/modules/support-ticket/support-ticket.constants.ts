export const SUPPORT_TICKET_REPOSITORY = Symbol('SUPPORT_TICKET_REPOSITORY');

export const SUPPORT_TICKET_STATUSES = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'] as const;
export const SUPPORT_TICKET_CATEGORIES = ['RIDE', 'FOOD', 'PAYMENT', 'ACCOUNT', 'SAFETY', 'OTHER'] as const;
export const SUPPORT_TICKET_PRIORITIES = ['LOW', 'NORMAL', 'HIGH', 'URGENT'] as const;
export const SUPPORT_TICKET_RELATED_TYPES = ['RIDE', 'FOOD_ORDER'] as const;
export const SUPPORT_APP_ROLES = ['CUSTOMER', 'DRIVER', 'MERCHANT'] as const;
export const SUPPORT_PUBLIC_ROLES = ['CUSTOMER', 'DRIVER', 'MERCHANT', 'OTHER'] as const;

/** Statuses a requester still waits on; they count toward the per-user open limit. */
export const SUPPORT_ACTIVE_STATUSES = ['OPEN', 'IN_PROGRESS'] as const;

/** Hard ceiling for any ticket text; the Admin setting SUPPORT_TICKET_TEXT_MAX_CHARS sits below it. */
export const SUPPORT_TEXT_HARD_MAX = 5000;
