import type { PlatformSettingKey } from './platform-settings.catalog.js';

/**
 * Seed values for settings that have no env bootstrap. They are inserted once (insert-if-absent)
 * by migrations `20261019140000_platform_fee_rating_window` / `20261019150000_voucher_sponsor_snapshot`, `prisma/seed.ts` and the settings
 * service on first use; after that only the admin Settings page changes them.
 *
 * Driver commissions start at 0 %: the actual rate is a business decision (OPEN-003) and is set by an
 * admin, never chosen in code. Commissions are per service (motorbike ride, car ride, food driver, merchant)
 * (migration 20261107090000_r20_commissions copies the old values).
 */
export const PLATFORM_SETTING_SEED_DEFAULTS: Readonly<Partial<Record<PlatformSettingKey, string>>> =
  {
    RATING_WINDOW_DAYS: '7',
    // DEC-PROD-062: commission per service (DRAFT; suggestions with sources are on the admin page).
    RIDE_COMMISSION_BIKE_PERCENT: '0',
    RIDE_COMMISSION_CAR_PERCENT: '0',
    FOOD_DRIVER_COMMISSION_PERCENT: '0',
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
    // Code confirmation is off by default (2026-10-29); admins can turn it back on.
    RIDE_PICKUP_CODE_REQUIRED: 'false',
    // DEC-PROD-036 rev 2026-10-29: delivery and handover codes are both opt-in.
    FOOD_DELIVERY_CODE_REQUIRED: 'false',
    PAYMENT_METHOD_REGISTRY: '{"methods":{}}',
    PAYMENT_WALLET_ENABLED: 'false',
    // Website links: all empty until an admin sets real ones (no placeholder links).
    PUBLIC_SITE_CONFIG: '{}',
    FOOD_DELIVERY_CODE_MAX_ATTEMPTS: '5',
    FOOD_HANDOVER_CODE_REQUIRED: 'false',
    // DEC-PROD-048 (DRAFT): KYC/KYB documents required by default (fail closed).
    ONBOARDING_DRIVER_KYC_REQUIRED: 'true',
    ONBOARDING_MERCHANT_KYB_REQUIRED: 'true',
    // DEC-PROD-037: S027 grace period (days) before a deleted account is anonymized.
    ACCOUNT_DELETION_GRACE_DAYS: '7',
    // DEC-PROD-045: forgot-password email code (same numbers as sign-up OTP, DEC-PROD-008).
    AUTH_PASSWORD_RESET_CODE_TTL_MINUTES: '10',
    AUTH_PASSWORD_RESET_MAX_ATTEMPTS: '5',
    AUTH_PASSWORD_RESET_MAX_PER_HOUR: '5',
    // DEC-PROD-056 (ASSUMED): 90 days covers the dispute/refund window; admin-editable.
    CHAT_RETENTION_DAYS: '90',
    // DEC-PROD-052: review login stays off until an admin enables it for a review cycle.
    APP_REVIEW_LOGIN_ENABLED: 'false',
    // (DEC-PROD-059) Dispatch lifecycle, fees, zones, debt.
    RIDE_REQUEST_WINDOW_SECONDS: '300',
    RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE: '80',
    RIDE_COUNTER_MAX_PERCENT_OF_OFFER: '150',
    RIDE_MAX_OFFER_EDITS_PER_DRIVER: '2',
    RIDE_ASSIGNED_START_TIMEOUT_MINUTES: '5',
    RIDE_EN_ROUTE_TIMEOUT_MINUTES: '30',
    RIDE_NO_SHOW_WAIT_MINUTES: '5',
    RIDE_FREE_CANCEL_MINUTES: '5',
    RIDE_CANCEL_FEE_BIKE_VND: '3000',
    RIDE_CANCEL_FEE_CAR_VND: '10000',
    FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES: '5',
    FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES: '30',
    FOOD_EARLY_ASSIGN_LEAD_MINUTES: '10',
    FOOD_MAX_DELIVERY_KM: '15',
    SERVICE_ZONE_ENFORCED: 'true',
    DRIVER_DEBT_LIMIT_VND: '200000',
    DISPATCH_REQUIRE_FRESH_PRESENCE: 'true',
    // (DEC-PROD-061) Negotiation rounds, cancellations, push, food cash model.
    RIDE_MAX_LIVE_OFFERS_PER_RIDE: '0',
    RIDE_MAX_FARE_RAISES_PER_RIDE: '3',
    // (DEC-PROD-035) One cached route per phase; throttled deviation re-route only.
    ROUTE_OFF_ROUTE_THRESHOLD_M: '150',
    ROUTE_REROUTE_MIN_INTERVAL_SECONDS: '120',
    CUSTOMER_CANCEL_LIMIT_COUNT: '3',
    CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS: '24',
    CUSTOMER_CANCEL_COOLDOWN_MINUTES: '30',
    DRIVER_CANCEL_RATE_WINDOW_DAYS: '7',
    DRIVER_CANCEL_RATE_WARN_PERCENT: '20',
    RIDE_REQUEST_PUSH_ENABLED: 'true',
    // Spoken "DealGo, có cuốc mới" sound on new ride / food job / merchant order pushes.
    NEW_JOB_CUSTOM_SOUND_ENABLED: 'true',
    // DEC-PROD-007: in-app voice calls between customer and assigned driver.
    VOICE_CALLS_ENABLED: 'true',
    // Multi-stop rides (DRAFT, flags OFF until legal/ops approve; Grab-like defaults).
    RIDE_MULTI_STOP_BIKE_ENABLED: 'false',
    RIDE_MULTI_STOP_CAR_ENABLED: 'false',
    RIDE_MAX_STOPS_BIKE: '1',
    RIDE_MAX_STOPS_CAR: '2',
    RIDE_STOP_FEE_BIKE_VND: '5000',
    RIDE_STOP_FEE_CAR_VND: '10000',
    RIDE_STOP_FREE_WAIT_MINUTES: '5',
    RIDE_STOP_WAIT_FEE_VND_PER_MINUTE: '1000',
    RIDE_REQUEST_PUSH_MAX_DRIVERS: '30',
    RIDE_REQUEST_REPUSH_INTERVAL_SEC: '30',
    RIDE_REQUEST_REPUSH_MAX: '3',
    FOOD_FAIL_MIN_WAIT_MINUTES: '10',
    FOOD_MERCHANT_COMMISSION_PERCENT: '20',
    FOOD_ORDER_CHANGE_RESPONSE_MINUTES: '5',
    RIDE_REPOST_RAISE_HINT_PERCENT: '10',
    // DEC-PROD-062 DRAFT: merchant commission settlement cycle (GrabFood pays weekly).
    MERCHANT_SETTLEMENT_CYCLE_DAYS: '7',
    // Map providers per capability; google needs a Google key (Admin › Cài đặt › Bản đồ or GOOGLE_MAPS_API_KEY).
    MAPS_SEARCH_PROVIDER: 'mapbox',
    MAPS_REVERSE_PROVIDER: 'mapbox',
    MAPS_ROUTE_PROVIDER: 'mapbox',
  };

