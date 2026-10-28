export type PlatformSettingValueTypeName = 'string' | 'number' | 'json';

export type PlatformSettingKey =
  | 'DRIVER_SEARCH_RADIUS_KM'
  | 'RIDE_OFFER_TTL_SECONDS'
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
  | 'RIDE_COMMISSION_BIKE_PERCENT'
  | 'RIDE_COMMISSION_CAR_PERCENT'
  | 'FOOD_DRIVER_COMMISSION_PERCENT'
  | 'VOUCHER_SHARED_PLATFORM_PERCENT'
  | 'RIDE_PICKUP_CODE_MAX_ATTEMPTS'
  | 'FOOD_DELIVERY_CODE_REQUIRED'
  | 'FOOD_DELIVERY_CODE_MAX_ATTEMPTS'
  | 'FOOD_HANDOVER_CODE_REQUIRED'
  | 'ONBOARDING_DRIVER_KYC_REQUIRED'
  | 'ONBOARDING_MERCHANT_KYB_REQUIRED'
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
  | 'AUTH_PASSWORD_RESET_MAX_PER_HOUR'
  | 'CHAT_RETENTION_DAYS'
  | 'APP_REVIEW_LOGIN_ENABLED'
  | 'APP_REVIEW_PHONE'
  | 'APP_REVIEW_EMAIL'
  | 'RIDE_REQUEST_WINDOW_SECONDS'
  | 'RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE'
  | 'RIDE_COUNTER_MAX_PERCENT_OF_OFFER'
  | 'RIDE_MAX_OFFER_EDITS_PER_DRIVER'
  | 'RIDE_ASSIGNED_START_TIMEOUT_MINUTES'
  | 'RIDE_EN_ROUTE_TIMEOUT_MINUTES'
  | 'RIDE_NO_SHOW_WAIT_MINUTES'
  | 'RIDE_FREE_CANCEL_MINUTES'
  | 'RIDE_CANCEL_FEE_BIKE_VND'
  | 'RIDE_CANCEL_FEE_CAR_VND'
  | 'FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES'
  | 'FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES'
  | 'FOOD_EARLY_ASSIGN_LEAD_MINUTES'
  | 'FOOD_MAX_DELIVERY_KM'
  | 'SERVICE_ZONE_ENFORCED'
  | 'DRIVER_DEBT_LIMIT_VND'
  | 'DISPATCH_REQUIRE_FRESH_PRESENCE'
  | 'RIDE_MAX_LIVE_OFFERS_PER_RIDE'
  | 'RIDE_MAX_FARE_RAISES_PER_RIDE'
  | 'ROUTE_OFF_ROUTE_THRESHOLD_M'
  | 'ROUTE_REROUTE_MIN_INTERVAL_SECONDS'
  | 'CUSTOMER_CANCEL_LIMIT_COUNT'
  | 'CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS'
  | 'CUSTOMER_CANCEL_COOLDOWN_MINUTES'
  | 'DRIVER_CANCEL_RATE_WINDOW_DAYS'
  | 'DRIVER_CANCEL_RATE_WARN_PERCENT'
  | 'RIDE_REQUEST_PUSH_ENABLED'
  | 'NEW_JOB_CUSTOM_SOUND_ENABLED'
  | 'RIDE_REQUEST_PUSH_MAX_DRIVERS'
  | 'FOOD_FAIL_MIN_WAIT_MINUTES'
  | 'FOOD_MERCHANT_COMMISSION_PERCENT'
  | 'FOOD_ORDER_CHANGE_RESPONSE_MINUTES'
  | 'RIDE_REPOST_RAISE_HINT_PERCENT'
  | 'MERCHANT_SETTLEMENT_CYCLE_DAYS'
  | 'VOICE_CALLS_ENABLED'
  | 'MAPS_SEARCH_PROVIDER'
  | 'MAPS_REVERSE_PROVIDER'
  | 'MAPS_ROUTE_PROVIDER'
  | 'RIDE_MULTI_STOP_BIKE_ENABLED'
  | 'RIDE_MULTI_STOP_CAR_ENABLED'
  | 'RIDE_MAX_STOPS_BIKE'
  | 'RIDE_MAX_STOPS_CAR'
  | 'RIDE_STOP_FEE_BIKE_VND'
  | 'RIDE_STOP_FEE_CAR_VND'
  | 'RIDE_STOP_FREE_WAIT_MINUTES'
  | 'RIDE_STOP_WAIT_FEE_VND_PER_MINUTE';

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
    // Hoa hồng chuyến xe máy, % trên cước tài xế thu (seed 0 – OPEN-003, admin chốt).
    // Tham khảo: inDrive ~10 %, GrabBike 20 % + phí nền tảng, Be ~24–30 %.
    key: 'RIDE_COMMISSION_BIKE_PERCENT',
    valueType: 'number',
    openIds: ['OPEN-003', 'DEC-PROD-014', 'DEC-PROD-062'],
    min: 0,
    max: 100,
    maxDecimals: 2,
    seeded: true,
  },
  {
    // Hoa hồng chuyến ô tô (seed 0 – OPEN-003). Tham khảo: inDrive ~10 %, GrabCar ~20–27 %.
    key: 'RIDE_COMMISSION_CAR_PERCENT',
    valueType: 'number',
    openIds: ['OPEN-003', 'DEC-PROD-014', 'DEC-PROD-062'],
    min: 0,
    max: 100,
    maxDecimals: 2,
    seeded: true,
  },
  {
    // Hoa hồng tài xế giao đồ ăn, % trên phí giao (seed 0). ShopeeFood: tài xế nhận
    // 100 % phí giao từ 23/05/2023; beFood: phí sử dụng ứng dụng ~10,5 %.
    key: 'FOOD_DRIVER_COMMISSION_PERCENT',
    valueType: 'number',
    openIds: ['OPEN-003', 'DEC-PROD-014', 'DEC-PROD-062'],
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
    // DEC-PROD-048 (DRAFT): false = driver applies without KYC documents; ops still approves
    // and the vehicle class stays mandatory.
    key: 'ONBOARDING_DRIVER_KYC_REQUIRED',
    valueType: 'json',
    openIds: ['DEC-PROD-048'],
    boolean: true,
    seeded: true,
  },
  {
    // DEC-PROD-048 (DRAFT): false = merchant applies without KYB documents; ops still approves.
    key: 'ONBOARDING_MERCHANT_KYB_REQUIRED',
    valueType: 'json',
    openIds: ['DEC-PROD-048'],
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
  {
    // DEC-PROD-056: chat messages older than this are purged by the worker (dispute window).
    key: 'CHAT_RETENTION_DAYS',
    valueType: 'number',
    openIds: ['DEC-PROD-056'],
    min: 7,
    max: 3650,
    seeded: true,
  },
  {
    // DEC-PROD-052: App Store / Play review sign-in. Off by default; turn on only during review.
    key: 'APP_REVIEW_LOGIN_ENABLED',
    valueType: 'json',
    openIds: ['DEC-PROD-052'],
    boolean: true,
    seeded: true,
  },
  {
    // DEC-PROD-052: the single phone number that accepts APP_REVIEW_OTP_CODE (E.164 or 0xxxxxxxxx).
    key: 'APP_REVIEW_PHONE',
    valueType: 'string',
    openIds: ['DEC-PROD-052'],
    optional: true,
    seeded: true,
  },
  {
    // DEC-PROD-052: the single email that accepts APP_REVIEW_OTP_CODE for email codes.
    key: 'APP_REVIEW_EMAIL',
    valueType: 'string',
    openIds: ['DEC-PROD-052'],
    optional: true,
    seeded: true,
  },

  {
    // How long a ride request collects offers (inDrive keeps a request open for minutes, not seconds).
    key: 'RIDE_REQUEST_WINDOW_SECONDS',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 60,
    max: 1800,
    seeded: true,
  },
  {
    // Customer bid floor as % of the reference fare (0 = class min only).
    key: 'RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 100,
    seeded: true,
  },
  {
    // A driver counter must be >= the customer bid and <= this % of it.
    key: 'RIDE_COUNTER_MAX_PERCENT_OF_OFFER',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 100,
    max: 300,
    seeded: true,
  },
  {
    // Times one driver may change an offer on one ride.
    key: 'RIDE_MAX_OFFER_EDITS_PER_DRIVER',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 10,
    seeded: true,
  },
  {
    // ASSIGNED with no "on my way" -> ride returns to bidding (0 = off).
    key: 'RIDE_ASSIGNED_START_TIMEOUT_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 60,
    seeded: true,
  },
  {
    // DRIVER_EN_ROUTE with no arrival -> ride returns to bidding (0 = off).
    key: 'RIDE_EN_ROUTE_TIMEOUT_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 180,
    seeded: true,
  },
  {
    // Driver waits this long after arriving before no-show (Grab/Be ~5 min).
    key: 'RIDE_NO_SHOW_WAIT_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 1,
    max: 30,
    seeded: true,
  },
  {
    // Customer cancels free within this many minutes of assignment.
    key: 'RIDE_FREE_CANCEL_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 30,
    seeded: true,
  },
  {
    // Late-cancel / no-show fee for motorbike classes (0 = off).
    key: 'RIDE_CANCEL_FEE_BIKE_VND',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 200000,
    seeded: true,
  },
  {
    // Late-cancel / no-show fee for car classes (0 = off).
    key: 'RIDE_CANCEL_FEE_CAR_VND',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 500000,
    seeded: true,
  },
  {
    // PLACED not accepted in time -> SYSTEM cancel (0 = off).
    key: 'FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 60,
    seeded: true,
  },
  {
    // READY with no driver -> SYSTEM cancel NO_DRIVER (0 = off).
    key: 'FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 240,
    seeded: true,
  },
  {
    // Drivers may claim this many minutes before the prep estimate ends (0 = only READY).
    key: 'FOOD_EARLY_ASSIGN_LEAD_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 60,
    seeded: true,
  },
  {
    // Max straight-line store->dropoff distance.
    key: 'FOOD_MAX_DELIVERY_KM',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 1,
    max: 50,
    seeded: true,
  },
  {
    // JSON boolean; rides/orders must start inside an ACTIVE service region.
    key: 'SERVICE_ZONE_ENFORCED',
    valueType: 'json',
    openIds: ['DEC-PROD-059'],
    boolean: true,
    seeded: true,
  },
  {
    // Unpaid fees above this block new jobs (inDrive blocks on negative balance).
    key: 'DRIVER_DEBT_LIMIT_VND',
    valueType: 'number',
    openIds: ['DEC-PROD-059'],
    min: 0,
    max: 10000000,
    seeded: true,
  },
  {
    // JSON boolean; drivers need online presence and a fresh location to see/offer/claim.
    key: 'DISPATCH_REQUIRE_FRESH_PRESENCE',
    valueType: 'json',
    openIds: ['DEC-PROD-059'],
    boolean: true,
    seeded: true,
  },
  {
    // 0 = không giới hạn (inDrive hiện mọi đề nghị cho khách chọn); 0–100.
    key: 'RIDE_MAX_LIVE_OFFERS_PER_RIDE',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 0,
    max: 100,
    seeded: true,
  },
  {
    // 3 — mỗi lần tăng giá mở vòng mới, tài xế được sửa giá lại; 0 = không giới hạn (0–20)
    key: 'RIDE_MAX_FARE_RAISES_PER_RIDE',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 0,
    max: 20,
    seeded: true,
  },
  {
    // 150 — tài xế lệch khỏi tuyến đã cache quá số mét này mới tính lại tuyến (30–2000)
    key: 'ROUTE_OFF_ROUTE_THRESHOLD_M',
    valueType: 'number',
    openIds: ['DEC-PROD-031'],
    min: 30,
    max: 2000,
    seeded: true,
  },
  {
    // 120 — tối thiểu bấy nhiêu giây giữa 2 lần gọi Directions cho 1 cuốc/đơn (30–1800)
    key: 'ROUTE_REROUTE_MIN_INTERVAL_SECONDS',
    valueType: 'number',
    openIds: ['DEC-PROD-031'],
    min: 30,
    max: 1800,
    seeded: true,
  },
  {
    // 3 — inDrive/Grab tạm khóa khi hủy nhiều; 0 = tắt (0–20)
    key: 'CUSTOMER_CANCEL_LIMIT_COUNT',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 0,
    max: 20,
    seeded: true,
  },
  {
    // 24 (1–168)
    key: 'CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 1,
    max: 168,
    seeded: true,
  },
  {
    // 30 — tính từ lần hủy gần nhất; 0 = tắt (0–1440)
    key: 'CUSTOMER_CANCEL_COOLDOWN_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 0,
    max: 1440,
    seeded: true,
  },
  {
    // 7 — Grab tính tỷ lệ hủy theo chu kỳ (1–90)
    key: 'DRIVER_CANCEL_RATE_WINDOW_DAYS',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 1,
    max: 90,
    seeded: true,
  },
  {
    // 20 — chỉ cảnh báo cho admin, chưa tự khóa (0–100)
    key: 'DRIVER_CANCEL_RATE_WARN_PERCENT',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 0,
    max: 100,
    seeded: true,
  },
  {
    // Bật — FCM ưu tiên cao cho tài xế gần (app nền/đóng), gộp theo chuyến, 1 lần/phút/tài xế
    key: 'RIDE_REQUEST_PUSH_ENABLED',
    valueType: 'json',
    openIds: ['DEC-PROD-061'],
    boolean: true,
    seeded: true,
  },
  {
    // Bật — push cuốc/đơn mới phát giọng "DealGo, có cuốc mới" (tắt: âm mặc định của máy)
    key: 'NEW_JOB_CUSTOM_SOUND_ENABLED',
    valueType: 'json',
    openIds: ['DEC-PROD-061'],
    boolean: true,
    seeded: true,
  },
  {
    // 30 — gần nhất trước; 0 = không gửi (0–200)
    key: 'RIDE_REQUEST_PUSH_MAX_DRIVERS',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 0,
    max: 200,
    seeded: true,
  },
  {
    // 10 — ShopeeFood: gọi ≥3 lần trong 10 phút (0–60)
    key: 'FOOD_FAIL_MIN_WAIT_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 0,
    max: 60,
    seeded: true,
  },
  {
    // 20 — GrabFood/ShopeeFood thu chiết khấu quán; ghi vào bảng đối soát quán (0–50)
    key: 'FOOD_MERCHANT_COMMISSION_PERCENT',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 0,
    max: 50,
    seeded: true,
  },
  {
    // 5 — quá hạn đơn tự hủy, không phí (1–30)
    key: 'FOOD_ORDER_CHANGE_RESPONSE_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 1,
    max: 30,
    seeded: true,
  },
  {
    // 10 — inDrive gợi ý tăng giá khi không có tài xế (0–50)
    key: 'RIDE_REPOST_RAISE_HINT_PERCENT',
    valueType: 'number',
    openIds: ['DEC-PROD-061'],
    min: 0,
    max: 50,
    seeded: true,
  },
  {
    // 7 — chu kỳ đối soát hoa hồng quán (ngày). GrabFood trả theo tuần (T2–CN) hoặc
    // theo ngày; sao kê mặc định và hạn nộp kế tiếp tính theo số ngày này (1–31).
    key: 'MERCHANT_SETTLEMENT_CYCLE_DAYS',
    valueType: 'number',
    openIds: ['DEC-PROD-062'],
    min: 1,
    max: 31,
    seeded: true,
  },
  {
    // Bật — khách và tài xế đang trong chuyến / đơn gọi thoại cho nhau trong app (LiveKit,
    // chỉ âm thanh, không ghi âm). Tắt = ẩn nút gọi, API gọi trả VOICE_DISABLED.
    key: 'VOICE_CALLS_ENABLED',
    valueType: 'json',
    openIds: ['DEC-PROD-007'],
    boolean: true,
    seeded: true,
  },
  {
    // mapbox | google — nguồn gợi ý địa chỉ khi gõ tìm (app + Admin). google cần Google Maps key (Admin › Cài đặt › Bản đồ hoặc GOOGLE_MAPS_API_KEY).
    key: 'MAPS_SEARCH_PROVIDER',
    valueType: 'string',
    openIds: ['DEC-PROD-045'],
    seeded: true,
  },
  {
    // mapbox | google — đổi toạ độ GPS / ghim thành địa chỉ.
    key: 'MAPS_REVERSE_PROVIDER',
    valueType: 'string',
    openIds: ['DEC-PROD-045'],
    seeded: true,
  },
  {
    // mapbox | google — quãng đường tính cước và đường vẽ trên bản đồ (mapbox = ROUTING_PROVIDER của env).
    key: 'MAPS_ROUTE_PROVIDER',
    valueType: 'string',
    openIds: ['DEC-PROD-045'],
    seeded: true,
  },
  {
    // Multi-stop rides on/off for this service (off = single destination only).
    key: 'RIDE_MULTI_STOP_BIKE_ENABLED',
    valueType: 'json',
    openIds: ['DEC-PROD-MULTISTOP'],
    boolean: true,
    seeded: true,
  },
  {
    // Multi-stop rides on/off for this service (off = single destination only).
    key: 'RIDE_MULTI_STOP_CAR_ENABLED',
    valueType: 'json',
    openIds: ['DEC-PROD-MULTISTOP'],
    boolean: true,
    seeded: true,
  },
  {
    key: 'RIDE_MAX_STOPS_BIKE',
    valueType: 'number',
    openIds: ['DEC-PROD-MULTISTOP'],
    min: 0,
    max: 5,
    seeded: true,
  },
  {
    key: 'RIDE_MAX_STOPS_CAR',
    valueType: 'number',
    openIds: ['DEC-PROD-MULTISTOP'],
    min: 0,
    max: 5,
    seeded: true,
  },
  {
    key: 'RIDE_STOP_FEE_BIKE_VND',
    valueType: 'number',
    openIds: ['DEC-PROD-MULTISTOP'],
    min: 0,
    max: 200000,
    seeded: true,
  },
  {
    key: 'RIDE_STOP_FEE_CAR_VND',
    valueType: 'number',
    openIds: ['DEC-PROD-MULTISTOP'],
    min: 0,
    max: 500000,
    seeded: true,
  },
  {
    key: 'RIDE_STOP_FREE_WAIT_MINUTES',
    valueType: 'number',
    openIds: ['DEC-PROD-MULTISTOP'],
    min: 0,
    max: 60,
    seeded: true,
  },
  {
    key: 'RIDE_STOP_WAIT_FEE_VND_PER_MINUTE',
    valueType: 'number',
    openIds: ['DEC-PROD-MULTISTOP'],
    min: 0,
    max: 50000,
    seeded: true,
  },
] as const;

/** Values accepted by the MAPS_*_PROVIDER settings. */
export const MAPS_PROVIDER_CHOICES = ['mapbox', 'google'] as const;
export type MapsProviderChoice = (typeof MAPS_PROVIDER_CHOICES)[number];
export const MAPS_PROVIDER_SETTING_KEYS = [
  'MAPS_SEARCH_PROVIDER',
  'MAPS_REVERSE_PROVIDER',
  'MAPS_ROUTE_PROVIDER',
] as const satisfies readonly PlatformSettingKey[];

export const PLATFORM_SETTING_KEYS = PLATFORM_SETTING_SPECS.map((s) => s.key);

export function isPlatformSettingKey(value: string): value is PlatformSettingKey {
  return (PLATFORM_SETTING_KEYS as readonly string[]).includes(value);
}

export function specForKey(key: PlatformSettingKey): PlatformSettingSpec {
  return PLATFORM_SETTING_SPECS.find((s) => s.key === key)!;
}
