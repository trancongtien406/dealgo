import type { StoreServiceMode } from './store-service-mode.js';

/** M022 — how new orders enter the kitchen queue (DEC-PROD-028). */
export type StoreAcceptMode = 'MANUAL' | 'AUTO';

export const STORE_ACCEPT_MODES = ['MANUAL', 'AUTO'] as const satisfies readonly StoreAcceptMode[];
/** Kitchen capacity cap the merchant may set; null = no cap. */
export const MAX_ACTIVE_ORDERS_LIMIT = 50;
export const PREP_MINUTES_MIN = 5;
export const PREP_MINUTES_MAX = 90;
/** M024 BUSY: extra prep minutes the merchant may add on top of the default. */
export const BUSY_EXTRA_MINUTES = [10, 15, 20, 30, 45, 60] as const;
/** Orders still in the kitchen count against the cap. */
export const KITCHEN_ACTIVE_STATUSES = ['PLACED', 'PREPARING'] as const;

export type StoreAcceptSettings = {
  acceptMode: StoreAcceptMode;
  maxActiveOrders: number | null;
  defaultPrepMinutes: number;
  busyExtraMinutes: number;
};

export const DEFAULT_ACCEPT_SETTINGS: StoreAcceptSettings = {
  acceptMode: 'MANUAL',
  maxActiveOrders: null,
  defaultPrepMinutes: 15,
  busyExtraMinutes: 15,
};

/** Prep estimate shown to customers and snapshotted on new orders. */
export function prepMinutesFor(settings: StoreAcceptSettings, effectiveMode: StoreServiceMode): number {
  return settings.defaultPrepMinutes + (effectiveMode === 'BUSY' ? settings.busyExtraMinutes : 0);
}

/** AUTO stores skip the manual accept step; the guard has already checked open + capacity. */
export function placementStatus(settings: Pick<StoreAcceptSettings, 'acceptMode'>): 'PLACED' | 'PREPARING' {
  return settings.acceptMode === 'AUTO' ? 'PREPARING' : 'PLACED';
}

export function atCapacity(settings: Pick<StoreAcceptSettings, 'maxActiveOrders'>, activeOrders: number): boolean {
  return settings.maxActiveOrders !== null && activeOrders >= settings.maxActiveOrders;
}

export function estimatedReadyAt(placedAt: Date, prepMinutes: number | null): Date | null {
  return prepMinutes === null ? null : new Date(placedAt.getTime() + prepMinutes * 60_000);
}

export function acceptSettingsFromRow(row: {
  acceptMode?: StoreAcceptMode | null;
  maxActiveOrders?: number | null;
  defaultPrepMinutes?: number | null;
  busyExtraMinutes?: number | null;
}): StoreAcceptSettings {
  return {
    acceptMode: row.acceptMode ?? DEFAULT_ACCEPT_SETTINGS.acceptMode,
    maxActiveOrders: row.maxActiveOrders ?? null,
    defaultPrepMinutes: row.defaultPrepMinutes ?? DEFAULT_ACCEPT_SETTINGS.defaultPrepMinutes,
    busyExtraMinutes: row.busyExtraMinutes ?? DEFAULT_ACCEPT_SETTINGS.busyExtraMinutes,
  };
}
