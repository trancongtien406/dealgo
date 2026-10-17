export type PlatformSettingValueTypeName = 'string' | 'number' | 'json';

export type PlatformSettingKey =
  | 'DRIVER_SEARCH_RADIUS_KM'
  | 'RIDE_OFFER_TTL_SECONDS'
  | 'RIDE_NEGOTIATION_MAX_ROUNDS'
  | 'RIDE_MIN_FARE_VND'
  | 'RIDE_MAX_FARE_VND'
  | 'RIDE_REFERENCE_VND_PER_KM'
  | 'FOOD_MIN_DELIVERY_VND'
  | 'FOOD_MAX_DELIVERY_VND'
  | 'FOOD_DELIVERY_VND_PER_KM'
  | 'CONTACT_WINDOW_MINUTES'
  | 'MAX_CONCURRENT_JOBS_PER_DRIVER'
  | 'PAYMENT_METHODS_ENABLED';

export type PlatformSettingSpec = {
  key: PlatformSettingKey;
  valueType: PlatformSettingValueTypeName;
  /** OPEN ids this knob relates to (documentation only). */
  openIds: readonly string[];
  optional?: boolean;
  min?: number;
  max?: number;
};

/**
 * Admin-editable platform configuration tunables. Secrets stay in env.
 * DB row overrides env bootstrap when present.
 */
export const PLATFORM_SETTING_SPECS: readonly PlatformSettingSpec[] = [
  {
    key: 'DRIVER_SEARCH_RADIUS_KM',
    valueType: 'number',
    openIds: ['OPEN-004'],
    min: 0.1,
    max: 100,
  },
  {
    key: 'RIDE_OFFER_TTL_SECONDS',
    valueType: 'number',
    openIds: ['OPEN-004', 'OPEN-019'],
    min: 1,
    max: 86_400,
  },
  {
    key: 'RIDE_NEGOTIATION_MAX_ROUNDS',
    valueType: 'number',
    openIds: ['OPEN-019'],
    optional: true,
    min: 1,
    max: 100,
  },
  {
    key: 'RIDE_MIN_FARE_VND',
    valueType: 'number',
    openIds: ['OPEN-003', 'OPEN-019'],
    min: 1,
    max: 2_147_483_647,
  },
  {
    key: 'RIDE_MAX_FARE_VND',
    valueType: 'number',
    openIds: ['OPEN-003', 'OPEN-019'],
    min: 1,
    max: 2_147_483_647,
  },
  {
    key: 'RIDE_REFERENCE_VND_PER_KM',
    valueType: 'number',
    openIds: ['OPEN-003', 'OPEN-019'],
    min: 1,
    max: 2_147_483_647,
  },
  {
    key: 'FOOD_MIN_DELIVERY_VND',
    valueType: 'number',
    openIds: ['OPEN-003'],
    min: 1,
    max: 2_147_483_647,
  },
  {
    key: 'FOOD_MAX_DELIVERY_VND',
    valueType: 'number',
    openIds: ['OPEN-003'],
    min: 1,
    max: 2_147_483_647,
  },
  {
    key: 'FOOD_DELIVERY_VND_PER_KM',
    valueType: 'number',
    openIds: ['OPEN-003'],
    min: 1,
    max: 2_147_483_647,
  },
  {
    key: 'CONTACT_WINDOW_MINUTES',
    valueType: 'number',
    openIds: ['OPEN-014', 'OPEN-021'],
    min: 1,
    max: 10_080,
  },
  {
    key: 'MAX_CONCURRENT_JOBS_PER_DRIVER',
    valueType: 'number',
    openIds: ['OPEN-005'],
    min: 1,
    max: 20,
  },
  {
    key: 'PAYMENT_METHODS_ENABLED',
    valueType: 'json',
    openIds: ['OPEN-002'],
  },
] as const;

export const PLATFORM_SETTING_KEYS = PLATFORM_SETTING_SPECS.map((s) => s.key);

export function isPlatformSettingKey(value: string): value is PlatformSettingKey {
  return (PLATFORM_SETTING_KEYS as readonly string[]).includes(value);
}

export function specForKey(key: PlatformSettingKey): PlatformSettingSpec {
  return PLATFORM_SETTING_SPECS.find((s) => s.key === key)!;
}
