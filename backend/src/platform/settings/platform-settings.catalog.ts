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
  | 'PAYMENT_METHODS_ENABLED'
  | 'RATING_WINDOW_DAYS'
  | 'PLATFORM_FEE_RIDE_PERCENT'
  | 'PLATFORM_FEE_FOOD_PERCENT'
  | 'VOUCHER_SHARED_PLATFORM_PERCENT'
  | 'RIDE_PICKUP_CODE_MAX_ATTEMPTS'
  | 'FOOD_DELIVERY_CODE_REQUIRED'
  | 'FOOD_DELIVERY_CODE_MAX_ATTEMPTS'
  | 'FOOD_HANDOVER_CODE_REQUIRED'
  | 'SUPPORT_TICKET_MAX_OPEN_PER_USER'
  | 'SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY'
  | 'SUPPORT_TICKET_TEXT_MAX_CHARS'
  | 'RATING_STORE_MIN_COUNT'
  | 'UPLOAD_MAX_FILE_KB'
  | 'MENU_ITEM_MAX_IMAGES'
  | 'UPLOAD_ALLOWED_TYPES'
  | 'UPLOAD_ORPHAN_MAX_AGE_HOURS'
  | 'ACCOUNT_DELETION_GRACE_DAYS'
  | 'AUTH_PASSWORD_RESET_CODE_TTL_MINUTES'
  | 'AUTH_PASSWORD_RESET_MAX_ATTEMPTS'
  | 'AUTH_PASSWORD_RESET_MAX_PER_HOUR';

/** Highest value an admin may set for UPLOAD_MAX_FILE_KB. */
export const UPLOAD_MAX_FILE_KB_CEILING = 5120;

/** Upload content types whose bytes the server can verify by signature. */
export const UPLOAD_SNIFFABLE_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
] as const;

export type PlatformSettingSpec = {
  key: PlatformSettingKey;
  valueType: PlatformSettingValueTypeName;
  /** OPEN ids this knob relates to (documentation only). */
  openIds: readonly string[];
  optional?: boolean;
  min?: number;
  max?: number;
  /** Numbers only: decimal places allowed (default 0 = integer). */
  maxDecimals?: number;
  /** Default comes from PLATFORM_SETTING_SEED_DEFAULTS (migration/seed), not env. */
  seeded?: true;
  /** JSON settings only: the value must be `true` or `false`. */
  boolean?: true;
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
  {
    key: 'RATING_WINDOW_DAYS',
    valueType: 'number',
    openIds: ['DEC-PROD-013'],
    min: 1,
    max: 365,
    seeded: true,
  },
  {
    key: 'PLATFORM_FEE_RIDE_PERCENT',
    valueType: 'number',
    openIds: ['OPEN-003', 'DEC-PROD-014'],
    min: 0,
    max: 100,
    maxDecimals: 2,
    seeded: true,
  },
  {
    key: 'PLATFORM_FEE_FOOD_PERCENT',
    valueType: 'number',
    openIds: ['OPEN-003', 'DEC-PROD-014'],
    min: 0,
    max: 100,
    maxDecimals: 2,
    seeded: true,
  },
  {
    key: 'VOUCHER_SHARED_PLATFORM_PERCENT',
    valueType: 'number',
    openIds: ['DEC-PROD-015'],
    min: 0,
    max: 100,
    maxDecimals: 2,
    seeded: true,
  },
  {
    key: 'RIDE_PICKUP_CODE_MAX_ATTEMPTS',
    valueType: 'number',
    openIds: ['DEC-PROD-017'],
    min: 1,
    max: 20,
    seeded: true,
  },
  {
    // DEC-PROD-036: JSON boolean; the driver must enter the customer's code to deliver.
    key: 'FOOD_DELIVERY_CODE_REQUIRED',
    valueType: 'json',
    openIds: ['DEC-PROD-036'],
    boolean: true,
    seeded: true,
  },
  {
    // DEC-PROD-036: wrong delivery / handover codes per order before that code locks.
    key: 'FOOD_DELIVERY_CODE_MAX_ATTEMPTS',
    valueType: 'number',
    openIds: ['DEC-PROD-036'],
    min: 1,
    max: 20,
    seeded: true,
  },
  {
    // DEC-PROD-036: JSON boolean; the driver must enter the merchant's handover code at pickup.
    key: 'FOOD_HANDOVER_CODE_REQUIRED',
    valueType: 'json',
    openIds: ['DEC-PROD-036'],
    boolean: true,
    seeded: true,
  },
  {
    key: 'SUPPORT_TICKET_MAX_OPEN_PER_USER',
    valueType: 'number',
    openIds: ['DEC-PROD-018'],
    min: 1,
    max: 50,
    seeded: true,
  },
  {
    key: 'SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY',
    valueType: 'number',
    openIds: ['DEC-PROD-018'],
    min: 1,
    max: 50,
    seeded: true,
  },
  {
    key: 'SUPPORT_TICKET_TEXT_MAX_CHARS',
    valueType: 'number',
    openIds: ['DEC-PROD-018'],
    min: 200,
    max: 5000,
    seeded: true,
  },
  {
    key: 'RATING_STORE_MIN_COUNT',
    valueType: 'number',
    openIds: ['DEC-PROD-019'],
    min: 1,
    max: 50,
    seeded: true,
  },
  {
    // Per-file cap for KYC/KYB documents and ticket attachments. The route body limit
    // (route-body-parsers.ts) is sized for this maximum.
    key: 'UPLOAD_MAX_FILE_KB',
    valueType: 'number',
    openIds: ['DEC-PROD-020'],
    min: 100,
    max: UPLOAD_MAX_FILE_KB_CEILING,
    seeded: true,
  },
  {
    key: 'MENU_ITEM_MAX_IMAGES',
    valueType: 'number',
    openIds: ['DEC-PROD-042'],
    min: 1,
    max: 8,
    seeded: true,
  },
  {
    // JSON array; each entry must be one of UPLOAD_SNIFFABLE_TYPES (content is verified).
    key: 'UPLOAD_ALLOWED_TYPES',
    valueType: 'json',
    openIds: ['DEC-PROD-020'],
    seeded: true,
  },
  {
    // DEC-PROD-022: stored files no record points to are deleted by the worker once older than
    // this. The floor keeps a file that is mid-request (stored, not yet saved) safe.
    key: 'UPLOAD_ORPHAN_MAX_AGE_HOURS',
    valueType: 'number',
    openIds: ['DEC-PROD-022'],
    min: 24,
    max: 2160,
    seeded: true,
  },
  {
    // DEC-PROD-037: days between the user confirming S027 deletion and the purge worker
    // anonymizing the account. 0 = purge on the next worker run (no restore window).
    key: 'ACCOUNT_DELETION_GRACE_DAYS',
    valueType: 'number',
    openIds: ['DEC-PROD-037'],
    min: 0,
    max: 90,
    seeded: true,
  },
  {
    // DEC-PROD-045: minutes an emailed forgot-password code stays valid.
    key: 'AUTH_PASSWORD_RESET_CODE_TTL_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-045', 'OPEN-020'],
    min: 5,
    max: 60,
    seeded: true,
  },
  {
    // DEC-PROD-045: wrong codes per challenge before it locks (resends do not reset it).
    key: 'AUTH_PASSWORD_RESET_MAX_ATTEMPTS',
    valueType: 'number',
    openIds: ['DEC-PROD-045', 'OPEN-020'],
    min: 3,
    max: 10,
    seeded: true,
  },
  {
    // DEC-PROD-045: reset challenges per email address per hour (inbox-flood guard).
    key: 'AUTH_PASSWORD_RESET_MAX_PER_HOUR',
    valueType: 'number',
    openIds: ['DEC-PROD-045', 'OPEN-020'],
    min: 1,
    max: 20,
    seeded: true,
  },
] as const;

export const PLATFORM_SETTING_KEYS = PLATFORM_SETTING_SPECS.map((s) => s.key);

export function isPlatformSettingKey(value: string): value is PlatformSettingKey {
  return (PLATFORM_SETTING_KEYS as readonly string[]).includes(value);
}

export function specForKey(key: PlatformSettingKey): PlatformSettingSpec {
  return PLATFORM_SETTING_SPECS.find((s) => s.key === key)!;
}
