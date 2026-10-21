import type { PlatformSettingKey } from './platform-settings.catalog.js';

/**
 * Seed values for settings that have no env bootstrap. They are inserted once (insert-if-absent)
 * by migrations `20261019140000_platform_fee_rating_window` / `20261019150000_voucher_sponsor_snapshot`, `prisma/seed.ts` and the settings
 * service on first use; after that only the admin Settings page changes them.
 *
 * Platform fees start at 0 %: the actual rate is a business decision (OPEN-003) and is set by an
 * admin, never chosen in code.
 */
export const PLATFORM_SETTING_SEED_DEFAULTS: Readonly<Partial<Record<PlatformSettingKey, string>>> =
  {
    RATING_WINDOW_DAYS: '7',
    PLATFORM_FEE_RIDE_PERCENT: '0',
    PLATFORM_FEE_FOOD_PERCENT: '0',
    // DEC-PROD-015: DealGo's share of a SHARED-sponsor voucher discount. 100 keeps the
    // DEC-PROD-009 behaviour (DealGo funds everything) until an admin agrees a split.
    VOUCHER_SHARED_PLATFORM_PERCENT: '100',
    // Store average shown only after this many ratings (rater privacy)
    RATING_STORE_MIN_COUNT: '3',
    // DEC-PROD-020: per-file upload cap (KB) and accepted types for documents/attachments.
    UPLOAD_MAX_FILE_KB: '4096',
    MENU_ITEM_MAX_IMAGES: '4',
    UPLOAD_ALLOWED_TYPES: '["image/jpeg","image/png","image/webp","application/pdf"]',
    // DEC-PROD-022: unreferenced stored files older than this many hours are removed.
    UPLOAD_ORPHAN_MAX_AGE_HOURS: '72',
    // Max characters for a ticket description or reply.
    SUPPORT_TICKET_TEXT_MAX_CHARS: '2000',
    // Website support-form tickets per phone/email in 24 hours.
    SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY: '3',
    // Open (not resolved/closed) app tickets one user may hold.
    SUPPORT_TICKET_MAX_OPEN_PER_USER: '5',
    // DEC-PROD-017: wrong pickup codes a driver may enter before the ride's code locks.
    RIDE_PICKUP_CODE_MAX_ATTEMPTS: '5',
    // DEC-PROD-036: delivery proof on by default; merchant↔driver handover code opt-in.
    FOOD_DELIVERY_CODE_REQUIRED: 'true',
    FOOD_DELIVERY_CODE_MAX_ATTEMPTS: '5',
    FOOD_HANDOVER_CODE_REQUIRED: 'false',
    // DEC-PROD-037: S027 grace period (days) before a deleted account is anonymized.
    ACCOUNT_DELETION_GRACE_DAYS: '7',
    // DEC-PROD-045: forgot-password email code (same numbers as sign-up OTP, DEC-PROD-008).
    AUTH_PASSWORD_RESET_CODE_TTL_MINUTES: '10',
    AUTH_PASSWORD_RESET_MAX_ATTEMPTS: '5',
    AUTH_PASSWORD_RESET_MAX_PER_HOUR: '5',
  };
