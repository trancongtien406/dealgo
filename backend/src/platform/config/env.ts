import { z } from 'zod';
import {
  apnsVoipEnvFrom,
  apnsVoipStatusFrom,
} from '../../integrations/push/apns-voip-sender.js';
import { resolveFcmCredentials } from '../../integrations/push/fcm-credentials.js';

export const DEV_JWT_ACCESS_SECRET = 'dev-only-change-me';
export const DEV_OPS_BOOTSTRAP_PASSWORD = 'change-me-dev-only';

export class EnvValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EnvValidationError';
  }
}

function blankToUndefined(value: unknown): unknown {
  if (typeof value !== 'string') {
    return value;
  }
  const trimmed = value.trim();
  return trimmed === '' ? undefined : trimmed;
}

const optionalString = z.preprocess(blankToUndefined, z.string().optional());

const optionalPositiveInt = z.preprocess(
  (value) =>
    value === undefined || value === null || value === '' ? undefined : value,
  z.coerce.number().int().positive().optional(),
);

const positiveInt = (defaultValue: number) =>
  z.preprocess(
    (value) =>
      value === undefined || value === null || value === '' ? undefined : value,
    z.coerce.number().int().positive().default(defaultValue),
  );

const fareVnd = (defaultValue: number) =>
  z.preprocess(
    (value) =>
      value === undefined || value === null || value === '' ? undefined : value,
    z.coerce.number().int().positive().max(2_147_483_647).default(defaultValue),
  );

const optionalBoolean = z.preprocess((value) => {
  if (value === undefined || value === null || value === '') {
    return undefined;
  }
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1') {
      return true;
    }
    if (normalized === 'false' || normalized === '0') {
      return false;
    }
  }
  return value;
}, z.boolean().optional());

const envSchema = z.object({
  NODE_ENV: z.preprocess(
    (value) =>
      value === undefined || value === null || value === '' ? undefined : value,
    z.enum(['development', 'test', 'production']).default('development'),
  ),
  /**
   * Where this build runs. Unset = derived from NODE_ENV (production → production,
   * otherwise local). Staging and production never bypass partner KYC/KYB by default.
   */
  DEPLOY_ENV: z.preprocess(
    (value) =>
      value === undefined || value === null || value === '' ? undefined : value,
    z.enum(['local', 'staging', 'production']).optional(),
  ),
  PORT: positiveInt(3001),
  DATABASE_URL: optionalString,
  DATABASE_POOL_MAX: positiveInt(10),
  DATABASE_CONNECT_TIMEOUT_MS: positiveInt(10_000),
  REDIS_URL: optionalString,
  JWT_ACCESS_SECRET: optionalString,
  // Access default 1h; refresh remains ~14d. Ops Admin BFF also refreshes on 401.
  JWT_ACCESS_TTL_SECONDS: positiveInt(3_600),
  JWT_REFRESH_TTL_SECONDS: positiveInt(1_209_600),
  WEBAUTHN_RP_ID: optionalString,
  WEBAUTHN_RP_NAME: optionalString,
  /** Comma-separated expected web origins; Android apk-key-hash origins are derived from APP_LINKS_ANDROID_CERT_SHA256. */
  WEBAUTHN_ORIGIN: optionalString,
  /** Universal/App Links + passkey association (DEC-PROD-058), served at /.well-known/*. */
  APP_LINKS_IOS_APP_IDS: optionalString,
  APP_LINKS_ANDROID_PACKAGE: optionalString,
  APP_LINKS_ANDROID_CERT_SHA256: optionalString,
  APP_LINKS_PATHS: optionalString,
  /** Public website origin for share links (DEC-PROD-021), e.g. https://dealgo.vn. */
  PUBLIC_WEB_BASE_URL: optionalString,
  MAPS_PROVIDER: optionalString,
  /** DEC-PROD-045: road geometry — none (unset default) | mapbox (preferred) | osrm (fallback). */
  ROUTING_PROVIDER: optionalString,
  /** Self-hosted OSRM base URL (no trailing path). Public demo OSRM = DEV only. */
  ROUTING_OSRM_URL: optionalString,
  /** Public Mapbox token for Geocoding / tiles wiring (pk.*). Prefer over Directions-only sk. */
  MAPBOX_ACCESS_TOKEN: optionalString,
  /** Server-side Mapbox Directions token (preferred provider; never sent to browsers). */
  MAPBOX_DIRECTIONS_TOKEN: optionalString,
  ROUTING_TIMEOUT_MS: positiveInt(4_000),
  /**
   * Optional Photon (OpenStreetMap) search endpoint merged into place search,
   * e.g. a self-hosted `http://photon:2322`. OSM carries the city street grid
   * Mapbox's VN data lacks. Unset → Mapbox only.
   */
  PLACES_OSM_SEARCH_URL: optionalString,
  GOONG_API_KEY: optionalString,
  GOOGLE_MAPS_API_KEY: optionalString,
  /** none | mock (non-prod) | esms (primary, DEC-PROD-050) | speedsms (secondary). */
  SMS_PROVIDER: optionalString,
  ESMS_API_KEY: optionalString,
  ESMS_SECRET_KEY: optionalString,
  ESMS_BRANDNAME: optionalString,
  /** eSMS SmsType: 2 = brandname CSKH (default). */
  ESMS_SMS_TYPE: optionalString,
  /** eSMS sandbox flag: when true eSMS validates but does not deliver (no charge). */
  ESMS_SANDBOX: optionalBoolean,
  ESMS_BASE_URL: optionalString,
  SPEEDSMS_ACCESS_TOKEN: optionalString,
  /** SpeedSMS sender: registered brandname, or the shared "Verify" sender (type 4) when unset. */
  SPEEDSMS_SENDER: optionalString,
  SPEEDSMS_SMS_TYPE: optionalString,
  SPEEDSMS_BASE_URL: optionalString,
  /** OTP message template; {code} and {minutes} are replaced. Must match the carrier-registered template. */
  SMS_OTP_TEMPLATE: optionalString,
  SMS_HTTP_TIMEOUT_MS: positiveInt(8_000),
  SMS_HTTP_MAX_ATTEMPTS: positiveInt(2),
  /** none | mock (non-prod) | smtp (generic, incl. SES/Brevo SMTP) | ses (Amazon SES v2 HTTPS API, DEC-PROD-051). */
  EMAIL_PROVIDER: optionalString,
  EMAIL_FROM: optionalString,
  SES_REGION: optionalString,
  SES_ACCESS_KEY_ID: optionalString,
  SES_SECRET_ACCESS_KEY: optionalString,
  SES_CONFIGURATION_SET: optionalString,
  EMAIL_HTTP_TIMEOUT_MS: positiveInt(10_000),
  /**
   * DEC-PROD-052 App Review sign-in. Fixed OTP used ONLY for the review phone/email configured by
   * admin (PlatformSettings APP_REVIEW_*) and only while APP_REVIEW_LOGIN_ENABLED=true. 6 digits.
   */
  APP_REVIEW_OTP_CODE: optionalString,
  /**
   * Express "trust proxy" (DEC-PROD-053). Unset/false = direct exposure (req.ip = socket).
   * Number = hops (e.g. 1 behind one load balancer), or a CSV of trusted subnets / "loopback".
   */
  TRUST_PROXY: optionalString,
  /** Error monitoring (DEC-PROD-054). Empty = disabled (no-op). */
  SENTRY_DSN: optionalString,
  SENTRY_ENVIRONMENT: optionalString,
  /** Release tag set per deploy (e.g. 2026.10.27-1930); groups issues by deploy. */
  SENTRY_RELEASE: optionalString,
  SENTRY_TRACES_SAMPLE_RATE: z.preprocess(
    (value) =>
      value === undefined || value === null || value === '' ? undefined : value,
    z.coerce.number().min(0).max(1).default(0),
  ),
  /** text (default dev) | json (default production) — structured logs for log shippers. */
  LOG_FORMAT: z.preprocess(
    (value) =>
      value === undefined || value === null || value === '' ? undefined : value,
    z.enum(['text', 'json']).optional(),
  ),
  /** Worker heartbeat cadence and the staleness after which /health/ready reports the worker down. */
  WORKER_HEARTBEAT_INTERVAL_MS: positiveInt(15_000),
  WORKER_HEARTBEAT_STALE_MS: positiveInt(60_000),
  /** Outbox lag alert threshold: oldest unprocessed message older than this marks readiness degraded. */
  OUTBOX_LAG_ALERT_MS: positiveInt(60_000),
  /** Optional webhook (e.g. Slack/Discord incoming URL) POSTed when the outbox-lag alert trips. */
  OPS_ALERT_WEBHOOK_URL: optionalString,
  /** DEC-PROD-056: how often the worker purges chat messages older than the admin retention setting. */
  CHAT_RETENTION_PURGE_INTERVAL_MS: positiveInt(3_600_000),
  KYC_MEDIA_RETENTION_INTERVAL_MS: positiveInt(3_600_000),
  /** Active PSP status reconciliation for online payments stuck pending (missed IPN). */
  PAYMENT_RECONCILE_INTERVAL_MS: positiveInt(120_000),
  SMTP_URL: optionalString,
  SMTP_HOST: optionalString,
  SMTP_PORT: optionalPositiveInt,
  SMTP_USER: optionalString,
  SMTP_PASSWORD: optionalString,
  SMTP_FROM: optionalString,
  SMTP_TLS: optionalBoolean,
  PUSH_PROVIDER: optionalString,
  FCM_PROJECT_ID: optionalString,
  FCM_CLIENT_EMAIL: optionalString,
  FCM_PRIVATE_KEY: optionalString,
  // Prefer over pasting PEM into .env. Relative paths resolve from process.cwd().
  FCM_SERVICE_ACCOUNT_PATH: optionalString,
  GOOGLE_APPLICATION_CREDENTIALS: optionalString,
  // APNs token-auth key (.p8, team-scoped, Sandbox & Production) for iOS PushKit (VoIP)
  // incoming-call pushes, topic `<APNS_BUNDLE_ID>.voip`. All optional: without key id +
  // team id + key, calls still ring through the normal FCM alert push.
  APNS_KEY_ID: optionalString,
  APNS_TEAM_ID: optionalString,
  APNS_PRIVATE_KEY: optionalString,
  APNS_KEY_PATH: optionalString,
  // Older name of APNS_KEY_PATH.
  APNS_PRIVATE_KEY_PATH: optionalString,
  APNS_BUNDLE_ID: optionalString,
  // sandbox | production; default production when NODE_ENV=production, else sandbox.
  APNS_ENV: optionalString,
  APNS_SANDBOX: optionalBoolean,
  PAYMENT_PROVIDER: optionalString,
  /** payOS (default) or VNPAY for driver prepayments; independent from job checkout. */
  DRIVER_TOP_UP_PROVIDER: optionalString,
  VNPAY_TMN_CODE: optionalString,
  VNPAY_HASH_SECRET: optionalString,
  VNPAY_URL: optionalString,
  MOMO_PARTNER_CODE: optionalString,
  MOMO_ACCESS_KEY: optionalString,
  MOMO_SECRET_KEY: optionalString,
  MOMO_ENDPOINT: optionalString,
  // Multi-method gateway (sandbox placeholders only; real keys live in the secret store).
  // Public HTTPS base the PSPs call back (IPN) and redirect to, e.g. https://api.dealgo.vn
  PAYMENT_PUBLIC_BASE_URL: optionalString,
  // App deeplink the return page bounces to, e.g. dealgo://payment-return
  PAYMENT_APP_RETURN_URL: optionalString,
  // VNPay merchant API (refund/querydr), sandbox: https://sandbox.vnpayment.vn/merchant_webapi/api/transaction
  VNPAY_API_URL: optionalString,
  ZALOPAY_APP_ID: optionalString,
  ZALOPAY_KEY1: optionalString,
  ZALOPAY_KEY2: optionalString,
  // sandbox: https://sb-openapi.zalopay.vn
  ZALOPAY_ENDPOINT: optionalString,
  // payOS payment links (A2A VietQR). Money settles to the merchant bank account; no payouts.
  PAYOS_CLIENT_ID: optionalString,
  PAYOS_API_KEY: optionalString,
  PAYOS_CHECKSUM_KEY: optionalString,
  // https://api-merchant.payos.vn (default)
  PAYOS_ENDPOINT: optionalString,
  SHOPEEPAY_CLIENT_ID: optionalString,
  SHOPEEPAY_SECRET_KEY: optionalString,
  SHOPEEPAY_MERCHANT_EXT_ID: optionalString,
  SHOPEEPAY_ENDPOINT: optionalString,
  CARD_GATEWAY_MERCHANT_ID: optionalString,
  CARD_GATEWAY_SECRET: optionalString,
  APPLE_PAY_MERCHANT_ID: optionalString,
  VOICE_PROVIDER: optionalString,
  LIVEKIT_URL: optionalString,
  LIVEKIT_API_KEY: optionalString,
  LIVEKIT_API_SECRET: optionalString,
  // Contact window in minutes for chat and voice communication after terminal status.
  CONTACT_WINDOW_MINUTES: positiveInt(120),
  // Chat at-rest encryption (AES-256-GCM). Base64 32-byte key; required in production.
  CHAT_ENCRYPTION_KEY: optionalString,
  CHAT_ENCRYPTION_KEY_VERSION: positiveInt(1),
  CHAT_ENCRYPTION_PREVIOUS_KEYS: optionalString,
  // Admin-managed integration credentials (email provider, map keys) at rest. Base64 32-byte key;
  // unset → Admin can view env defaults but cannot save credentials.
  SECRETS_ENCRYPTION_KEY: optionalString,
  KYC_STORAGE_PROVIDER: optionalString,
  // memory | local | s3 (DEC-PROD-020); see platform/storage/storage.module.ts for defaults.
  OBJECT_STORAGE_PROVIDER: optionalString,
  OBJECT_STORAGE_LOCAL_DIR: optionalString,
  OPS_BOOTSTRAP_EMAIL: optionalString,
  OPS_BOOTSTRAP_PASSWORD: optionalString,
  S3_ENDPOINT: optionalString,
  S3_REGION: optionalString,
  S3_BUCKET: optionalString,
  S3_ACCESS_KEY_ID: optionalString,
  S3_SECRET_ACCESS_KEY: optionalString,
  // Bootstrap defaults for Admin PlatformSettings (DB overrides when present).
  RIDE_OFFER_TTL_SECONDS: positiveInt(20),
  RIDE_MIN_FARE_VND: fareVnd(10_000),
  RIDE_MAX_FARE_VND: fareVnd(500_000),
  RIDE_REFERENCE_VND_PER_KM: fareVnd(5_000),
  FOOD_MIN_DELIVERY_VND: fareVnd(5_000),
  FOOD_MAX_DELIVERY_VND: fareVnd(100_000),
  // Per-km delivery quote; clamped by FOOD_MIN/MAX after distance.
  FOOD_DELIVERY_VND_PER_KM: fareVnd(3_000),
  // Driver search radius in km for dispatch queries.
  DRIVER_SEARCH_RADIUS_KM: z.preprocess(
    (value) =>
      value === undefined || value === null || value === '' ? undefined : value,
    z.coerce.number().positive().max(100).default(5),
  ),
  // Maximum concurrent active jobs per driver — enforced on food claim + ride select.
  MAX_CONCURRENT_JOBS_PER_DRIVER: positiveInt(1),
  // PAYMENT_METHODS_ENABLED was retired: methods are managed by PAYMENT_METHOD_REGISTRY (Admin › Thanh toán).
  // Cap when driver omits lat/lng so open/ready lists stay bounded.
  DISPATCH_FALLBACK_LIMIT: positiveInt(20),
  // DEC-PROD-031 rev 2026-10-24 adaptive GPS (DRAFT defaults; Fleet Engine range 5–60 s).
  DRIVER_LOCATION_ON_TRIP_INTERVAL_MS: positiveInt(5_000),
  DRIVER_LOCATION_IDLE_INTERVAL_MS: positiveInt(15_000),
  DRIVER_LOCATION_ON_TRIP_MIN_DISTANCE_M: positiveInt(10),
  DRIVER_LOCATION_IDLE_MIN_DISTANCE_M: positiveInt(50),
  DRIVER_LOCATION_MAX_SILENCE_MS: positiveInt(30_000),
  DRIVER_LOCATION_MIN_ACCEPT_INTERVAL_MS: positiveInt(1_000),
  OTP_THROTTLE_TTL_MS: positiveInt(60_000),
  OTP_THROTTLE_LIMIT: positiveInt(10),
  /** DEC-PROD-044: SMS OTP sends per phone number per window (on top of the per-IP limit). */
  OTP_PHONE_LIMIT: positiveInt(5),
  OTP_PHONE_WINDOW_MS: positiveInt(900_000),
  // Background workers (BullMQ when REDIS_URL up; interval fallback in non-prod).
  RIDE_EXPIRY_INTERVAL_MS: positiveInt(5_000),
  OUTBOX_RELAY_INTERVAL_MS: positiveInt(2_000),
  /** DEC-PROD-022: how often the worker sweeps unreferenced uploads (age threshold is an admin setting). */
  UPLOAD_ORPHAN_CLEANUP_INTERVAL_MS: positiveInt(21_600_000),
  /** DEC-PROD-037: how often the worker anonymizes accounts whose deletion grace period ended. */
  ACCOUNT_PURGE_INTERVAL_MS: positiveInt(3_600_000),
  // When true, skip APPROVED KYC/KYB for DRIVER listOpen / FOOD claim after ACTIVE grant.
  // Defaults to true only when DEPLOY_ENV is local; false on staging/production.
  // An explicit true is rejected when NODE_ENV or DEPLOY_ENV is production.
  PARTNER_ELIGIBILITY_BYPASS: optionalBoolean,
  // OPEN-006 scaffold: when true, Car DRIVER submit/offer requires VEHICLE_INSURANCE.
  // Defaults: true in production (fail closed); false outside production unless set.
  // No vendor API keys — owner loads secrets later (OPEN-008).
  PARTNER_CAR_KYC_EXTRA_DOCS: optionalBoolean,
  // t52u (DRAFT): optional AI vision pre-check for KYC uploads. Blank = disabled (manual review only).
  SWAGGER_ENABLED: optionalBoolean,
  CORS_ALLOWED_ORIGINS: optionalString,
});

export type AppEnv = z.infer<typeof envSchema>;

export function loadEnv(source: Record<string, unknown>): AppEnv {
  const parsed = envSchema.safeParse(applyLocalEnvAliases(source));
  if (!parsed.success) {
    const details = parsed.error.issues
      .map((issue) => `${issue.path.join('.') || 'env'}: ${issue.message}`)
      .join('; ');
    throw new EnvValidationError(details);
  }

  assertChatEncryptionKeys(parsed.data);
  assertSecretsEncryptionKey(parsed.data);
  assertAppReviewCode(parsed.data);
  assertNoProductionBypass(parsed.data);
  assertProductionProviders(parsed.data);
  assertVoiceConfig(parsed.data);
  if (parsed.data.RIDE_MIN_FARE_VND > parsed.data.RIDE_MAX_FARE_VND) {
    throw new EnvValidationError(
      'RIDE_MIN_FARE_VND must not exceed RIDE_MAX_FARE_VND',
    );
  }
  if (parsed.data.FOOD_MIN_DELIVERY_VND > parsed.data.FOOD_MAX_DELIVERY_VND) {
    throw new EnvValidationError(
      'FOOD_MIN_DELIVERY_VND must not exceed FOOD_MAX_DELIVERY_VND',
    );
  }
  return parsed.data;
}

/**
 * In-app voice calls (DEC-PROD-007). VOICE_PROVIDER: unset or `none` = calls unavailable (the
 * call API answers VOICE_UNAVAILABLE), `mock` = fake tokens for tests (never production),
 * `livekit` = real calls; then LIVEKIT_URL and both LIVEKIT_API_KEY / LIVEKIT_API_SECRET are
 * required, and production needs a wss:// URL and a secret of at least 32 characters.
 */
function assertVoiceConfig(env: AppEnv): void {
  const provider = env.VOICE_PROVIDER;
  if (
    provider !== undefined &&
    !['none', 'mock', 'livekit'].includes(provider)
  ) {
    throw new EnvValidationError(
      'VOICE_PROVIDER must be one of none, mock, livekit',
    );
  }
  if (Boolean(env.LIVEKIT_API_KEY) !== Boolean(env.LIVEKIT_API_SECRET)) {
    throw new EnvValidationError(
      'LIVEKIT_API_KEY and LIVEKIT_API_SECRET must be set together',
    );
  }
  if (provider !== 'livekit') {
    return;
  }
  if (!env.LIVEKIT_URL || !env.LIVEKIT_API_KEY || !env.LIVEKIT_API_SECRET) {
    throw new EnvValidationError(
      'VOICE_PROVIDER=livekit requires LIVEKIT_URL, LIVEKIT_API_KEY and LIVEKIT_API_SECRET',
    );
  }
  if (!/^wss?:\/\//.test(env.LIVEKIT_URL)) {
    throw new EnvValidationError('LIVEKIT_URL must start with ws:// or wss://');
  }
  if (env.NODE_ENV === 'production') {
    if (!env.LIVEKIT_URL.startsWith('wss://')) {
      throw new EnvValidationError(
        'LIVEKIT_URL must use wss:// when NODE_ENV=production (ws:// is for local dev only; ' +
          'self-hosted: wss://livekit.<domain>, see deploy/livekit)',
      );
    }
    if (env.LIVEKIT_API_SECRET.length < 32) {
      throw new EnvValidationError(
        'LIVEKIT_API_SECRET must be at least 32 characters when NODE_ENV=production',
      );
    }
  }
}

/**
 * DX aliases for common local .env mistakes. Does not invent production policy.
 * - JWT_SECRET → JWT_ACCESS_SECRET when the latter is unset
 * - SMS/EMAIL_PROVIDER=fake → mock; PAYMENT_PROVIDER=fake → sandbox
 * - S3_BUCKET_NAME → S3_BUCKET; S3_API_ENDPOINT → S3_ENDPOINT when unset
 * - SMTP_HOST/PORT/USER/PASSWORD → SMTP_URL when SMTP_URL unset
 */
export function applyLocalEnvAliases(
  source: Record<string, unknown>,
): Record<string, unknown> {
  const next: Record<string, unknown> = { ...source };

  const accessSecret = blankToUndefined(next.JWT_ACCESS_SECRET);
  const legacyJwt = blankToUndefined(next.JWT_SECRET);
  if (accessSecret === undefined && typeof legacyJwt === 'string') {
    next.JWT_ACCESS_SECRET = legacyJwt;
  }

  next.SMS_PROVIDER = mapProviderAlias(next.SMS_PROVIDER, { fake: 'mock' });
  next.EMAIL_PROVIDER = mapProviderAlias(next.EMAIL_PROVIDER, { fake: 'mock' });
  next.PAYMENT_PROVIDER = mapProviderAlias(next.PAYMENT_PROVIDER, {
    fake: 'sandbox',
    none: CASH_ONLY_PAYMENT_PROVIDER,
    cash: CASH_ONLY_PAYMENT_PROVIDER,
    cod: CASH_ONLY_PAYMENT_PROVIDER,
    'cash-only': CASH_ONLY_PAYMENT_PROVIDER,
  });
  next.SMS_PROVIDER = lowerProvider(next.SMS_PROVIDER);
  next.EMAIL_PROVIDER = lowerProvider(next.EMAIL_PROVIDER);
  next.PUSH_PROVIDER = lowerProvider(next.PUSH_PROVIDER);
  next.MAPS_PROVIDER = lowerProvider(next.MAPS_PROVIDER);

  const bucket = blankToUndefined(next.S3_BUCKET);
  const legacyBucket = blankToUndefined(next.S3_BUCKET_NAME);
  if (bucket === undefined && typeof legacyBucket === 'string') {
    next.S3_BUCKET = legacyBucket;
  }

  const endpoint = blankToUndefined(next.S3_ENDPOINT);
  const apiEndpoint = blankToUndefined(next.S3_API_ENDPOINT);
  if (endpoint === undefined && typeof apiEndpoint === 'string') {
    next.S3_ENDPOINT = apiEndpoint;
  }

  if (blankToUndefined(next.SMTP_URL) === undefined) {
    const built = buildSmtpUrlFromDiscrete(next);
    if (built) {
      next.SMTP_URL = built;
    }
  }

  return next;
}

function buildSmtpUrlFromDiscrete(
  source: Record<string, unknown>,
): string | undefined {
  const host = blankToUndefined(source.SMTP_HOST);
  if (typeof host !== 'string') {
    return undefined;
  }
  const portRaw = blankToUndefined(source.SMTP_PORT);
  const port =
    typeof portRaw === 'string' || typeof portRaw === 'number'
      ? Number(portRaw)
      : 587;
  if (!Number.isFinite(port) || port <= 0) {
    return undefined;
  }
  const user = blankToUndefined(source.SMTP_USER);
  const password = blankToUndefined(source.SMTP_PASSWORD);
  const tls = blankToUndefined(source.SMTP_TLS);
  const useImplicitTls =
    tls === true || tls === 'true' || tls === '1' || port === 465;
  const scheme = useImplicitTls && port === 465 ? 'smtps' : 'smtp';
  if (typeof user === 'string' && typeof password === 'string') {
    return `${scheme}://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}`;
  }
  return `${scheme}://${host}:${port}`;
}

function mapProviderAlias(
  value: unknown,
  aliases: Record<string, string>,
): unknown {
  if (typeof value !== 'string') {
    return value;
  }
  const normalized = value.trim().toLowerCase();
  return aliases[normalized] ?? value.trim();
}

/** Resolved deploy target (DEPLOY_ENV, else derived from NODE_ENV). */
export function deployEnvOf(
  env: Pick<AppEnv, 'DEPLOY_ENV' | 'NODE_ENV'>,
): 'local' | 'staging' | 'production' {
  return (
    env.DEPLOY_ENV ?? (env.NODE_ENV === 'production' ? 'production' : 'local')
  );
}

function assertNoProductionBypass(env: AppEnv): void {
  if (
    env.PARTNER_ELIGIBILITY_BYPASS === true &&
    (env.NODE_ENV === 'production' || env.DEPLOY_ENV === 'production')
  ) {
    throw new EnvValidationError(
      'PARTNER_ELIGIBILITY_BYPASS=true is not allowed in production (KYC/KYB must be approved)',
    );
  }
}

function assertProductionProviders(env: AppEnv): void {
  if (env.NODE_ENV !== 'production') {
    return;
  }

  if (
    !env.JWT_ACCESS_SECRET ||
    env.JWT_ACCESS_SECRET === DEV_JWT_ACCESS_SECRET
  ) {
    throw new EnvValidationError(
      'JWT_ACCESS_SECRET must be set to a non-development value when NODE_ENV=production',
    );
  }

  if (!env.CHAT_ENCRYPTION_KEY) {
    throw new EnvValidationError(
      'CHAT_ENCRYPTION_KEY must be set when NODE_ENV=production (chat at-rest encryption)',
    );
  }

  if (env.SMS_PROVIDER === 'mock') {
    throw new EnvValidationError(
      'SMS_PROVIDER=mock is not allowed when NODE_ENV=production',
    );
  }
  assertSmsProviderConfigured(env);
  assertEmailProviderConfigured(env);

  if (env.PUSH_PROVIDER === 'mock') {
    throw new EnvValidationError(
      'PUSH_PROVIDER=mock is not allowed when NODE_ENV=production',
    );
  }
  if (env.PUSH_PROVIDER !== 'fcm') {
    throw new EnvValidationError(
      'PUSH_PROVIDER must be fcm when NODE_ENV=production',
    );
  }
  if (
    !resolveFcmCredentials({
      projectId: env.FCM_PROJECT_ID,
      clientEmail: env.FCM_CLIENT_EMAIL,
      privateKey: env.FCM_PRIVATE_KEY,
      serviceAccountPath: env.FCM_SERVICE_ACCOUNT_PATH,
      googleApplicationCredentials: env.GOOGLE_APPLICATION_CREDENTIALS,
    })
  ) {
    throw new EnvValidationError(
      'PUSH_PROVIDER=fcm requires FCM_PROJECT_ID/FCM_CLIENT_EMAIL/FCM_PRIVATE_KEY or a readable FCM_SERVICE_ACCOUNT_PATH when NODE_ENV=production',
    );
  }

  assertMapsAndRoutingConfigured(env);
  assertApnsVoipUsable(env);

  if (env.VOICE_PROVIDER === 'mock') {
    throw new EnvValidationError(
      'VOICE_PROVIDER=mock is not allowed when NODE_ENV=production',
    );
  }

  if (!env.PAYMENT_PROVIDER) {
    throw new EnvValidationError(
      'PAYMENT_PROVIDER must be configured when NODE_ENV=production',
    );
  }

  if (env.PAYMENT_PROVIDER === 'sandbox') {
    throw new EnvValidationError(
      'PAYMENT_PROVIDER=sandbox is not allowed when NODE_ENV=production (use cash-only for a COD-only launch)',
    );
  }
  if (
    env.PAYMENT_PROVIDER === 'vnpay' &&
    !(env.VNPAY_TMN_CODE && env.VNPAY_HASH_SECRET && env.VNPAY_URL)
  ) {
    throw new EnvValidationError(
      'PAYMENT_PROVIDER=vnpay requires VNPAY_TMN_CODE, VNPAY_HASH_SECRET and VNPAY_URL when NODE_ENV=production',
    );
  }
  if (
    env.PAYMENT_PROVIDER === 'momo' &&
    !(
      env.MOMO_PARTNER_CODE &&
      env.MOMO_ACCESS_KEY &&
      env.MOMO_SECRET_KEY &&
      env.MOMO_ENDPOINT
    )
  ) {
    throw new EnvValidationError(
      'PAYMENT_PROVIDER=momo requires MOMO_PARTNER_CODE, MOMO_ACCESS_KEY, MOMO_SECRET_KEY and MOMO_ENDPOINT when NODE_ENV=production',
    );
  }
  if (!PRODUCTION_PAYMENT_PROVIDERS.has(env.PAYMENT_PROVIDER)) {
    throw new EnvValidationError(
      `PAYMENT_PROVIDER must be one of ${[...PRODUCTION_PAYMENT_PROVIDERS].join(', ')} when NODE_ENV=production`,
    );
  }
}

/** DEC-PROD-050: `cash-only` (alias `none`) is an explicit COD-only launch; online PSP disabled. */
export const CASH_ONLY_PAYMENT_PROVIDER = 'cash-only';
const PRODUCTION_PAYMENT_PROVIDERS = new Set([
  'vnpay',
  'momo',
  CASH_ONLY_PAYMENT_PROVIDER,
]);

export function isCashOnlyPaymentProvider(
  provider: string | undefined,
): boolean {
  return provider === CASH_ONLY_PAYMENT_PROVIDER;
}

/** Providers whose name is set must have their keys; unset/`none` means the method stays disabled. */
function assertSmsProviderConfigured(env: AppEnv): void {
  const provider = env.SMS_PROVIDER;
  if (provider === undefined || provider === 'none') {
    return;
  }
  if (provider === 'esms') {
    if (!env.ESMS_API_KEY || !env.ESMS_SECRET_KEY || !env.ESMS_BRANDNAME) {
      throw new EnvValidationError(
        'SMS_PROVIDER=esms requires ESMS_API_KEY, ESMS_SECRET_KEY and ESMS_BRANDNAME when NODE_ENV=production',
      );
    }
    if (env.ESMS_SANDBOX === true) {
      throw new EnvValidationError(
        'ESMS_SANDBOX=true is not allowed when NODE_ENV=production',
      );
    }
    return;
  }
  if (provider === 'speedsms') {
    if (!env.SPEEDSMS_ACCESS_TOKEN) {
      throw new EnvValidationError(
        'SMS_PROVIDER=speedsms requires SPEEDSMS_ACCESS_TOKEN when NODE_ENV=production',
      );
    }
    return;
  }
  throw new EnvValidationError(
    `SMS_PROVIDER=${provider} is not supported (use esms, speedsms or none)`,
  );
}

function assertEmailProviderConfigured(env: AppEnv): void {
  const provider = env.EMAIL_PROVIDER;
  if (provider === undefined || provider === 'none') {
    return;
  }
  if (provider === 'mock') {
    throw new EnvValidationError(
      'EMAIL_PROVIDER=mock is not allowed when NODE_ENV=production',
    );
  }
  if (provider === 'smtp') {
    if (!env.SMTP_URL) {
      throw new EnvValidationError(
        'EMAIL_PROVIDER=smtp requires SMTP_URL (or SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASSWORD) when NODE_ENV=production',
      );
    }
    return;
  }
  if (provider === 'ses') {
    if (
      !env.SES_REGION ||
      !env.SES_ACCESS_KEY_ID ||
      !env.SES_SECRET_ACCESS_KEY
    ) {
      throw new EnvValidationError(
        'EMAIL_PROVIDER=ses requires SES_REGION, SES_ACCESS_KEY_ID and SES_SECRET_ACCESS_KEY when NODE_ENV=production',
      );
    }
    if (!(env.EMAIL_FROM ?? env.SMTP_FROM)) {
      throw new EnvValidationError(
        'EMAIL_PROVIDER=ses requires EMAIL_FROM (a verified SES identity)',
      );
    }
    return;
  }
  throw new EnvValidationError(
    `EMAIL_PROVIDER=${provider} is not supported (use ses, smtp or none)`,
  );
}

const PUBLIC_DEMO_OSRM_HOST = 'router.project-osrm.org';

function assertMapsAndRoutingConfigured(env: AppEnv): void {
  const maps = env.MAPS_PROVIDER;
  const mapsKey =
    maps === 'mapbox'
      ? (env.MAPBOX_ACCESS_TOKEN ?? env.MAPBOX_DIRECTIONS_TOKEN)
      : maps === 'goong'
        ? env.GOONG_API_KEY
        : maps === 'google'
          ? env.GOOGLE_MAPS_API_KEY
          : undefined;
  if (!maps || maps === 'mock' || maps === 'none') {
    throw new EnvValidationError(
      'MAPS_PROVIDER must be mapbox, goong or google when NODE_ENV=production',
    );
  }
  if (!mapsKey) {
    throw new EnvValidationError(
      `MAPS_PROVIDER=${maps} requires its API key/token when NODE_ENV=production`,
    );
  }

  const routing = env.ROUTING_PROVIDER?.toLowerCase();
  if (!routing || routing === 'none') {
    throw new EnvValidationError(
      'ROUTING_PROVIDER must be mapbox or osrm when NODE_ENV=production (route geometry and ETA)',
    );
  }
  if (routing === 'mapbox' && !env.MAPBOX_DIRECTIONS_TOKEN) {
    throw new EnvValidationError(
      'ROUTING_PROVIDER=mapbox requires MAPBOX_DIRECTIONS_TOKEN when NODE_ENV=production',
    );
  }
  if (routing === 'osrm') {
    const url = env.ROUTING_OSRM_URL;
    if (!url || url.includes(PUBLIC_DEMO_OSRM_HOST)) {
      throw new EnvValidationError(
        'ROUTING_PROVIDER=osrm requires a self-hosted ROUTING_OSRM_URL (the public demo server is dev-only)',
      );
    }
  }
  if (routing !== 'mapbox' && routing !== 'osrm') {
    throw new EnvValidationError(
      `ROUTING_PROVIDER=${routing} is not supported (use mapbox or osrm)`,
    );
  }
}

/**
 * Validates chat key shape in every environment so a malformed dev key fails at boot with a
 * clear message instead of on the first chat message.
 */
export function assertChatEncryptionKeys(
  env: Pick<AppEnv, 'CHAT_ENCRYPTION_KEY' | 'CHAT_ENCRYPTION_PREVIOUS_KEYS'>,
): void {
  if (
    env.CHAT_ENCRYPTION_KEY !== undefined &&
    !isBase64Key32(env.CHAT_ENCRYPTION_KEY)
  ) {
    throw new EnvValidationError(
      'CHAT_ENCRYPTION_KEY must be base64 of exactly 32 bytes (generate: openssl rand -base64 32)',
    );
  }
  for (const entry of (env.CHAT_ENCRYPTION_PREVIOUS_KEYS ?? '').split(',')) {
    const trimmed = entry.trim();
    if (!trimmed) continue;
    const idx = trimmed.indexOf(':');
    const version = Number(trimmed.slice(0, idx));
    if (
      idx <= 0 ||
      !Number.isInteger(version) ||
      version <= 0 ||
      !isBase64Key32(trimmed.slice(idx + 1))
    ) {
      throw new EnvValidationError(
        'CHAT_ENCRYPTION_PREVIOUS_KEYS entries must be version:base64 (32-byte keys)',
      );
    }
  }
}

function assertSecretsEncryptionKey(env: Pick<AppEnv, 'SECRETS_ENCRYPTION_KEY'>): void {
  if (env.SECRETS_ENCRYPTION_KEY !== undefined && !isBase64Key32(env.SECRETS_ENCRYPTION_KEY)) {
    throw new EnvValidationError(
      'SECRETS_ENCRYPTION_KEY must be base64 of exactly 32 bytes (generate: openssl rand -base64 32)',
    );
  }
}

function isBase64Key32(raw: string): boolean {
  const value = raw.trim();
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value)) {
    return false;
  }
  return Buffer.from(value, 'base64').length === 32;
}

function assertAppReviewCode(env: AppEnv): void {
  if (
    env.APP_REVIEW_OTP_CODE !== undefined &&
    !/^\d{6}$/.test(env.APP_REVIEW_OTP_CODE)
  ) {
    throw new EnvValidationError(
      'APP_REVIEW_OTP_CODE must be exactly 6 digits',
    );
  }
}

function lowerProvider(value: unknown): unknown {
  return typeof value === 'string' ? value.trim().toLowerCase() : value;
}

/**
 * VoIP pushes are optional, but a half-done APNs setup in production (key file missing,
 * wrong key, ids missing, bad APNS_ENV) would silently stop CallKit ringing, so fail fast.
 * Nothing configured at all is fine: push.module logs that calls ring via the FCM alert.
 */
function assertApnsVoipUsable(env: AppEnv): void {
  const status = apnsVoipStatusFrom(apnsVoipEnvFrom((key) => env[key]));
  if (status.config || status.reason === 'missing') {
    return;
  }
  throw new EnvValidationError(
    `APNs VoIP config is incomplete when NODE_ENV=production: ${status.detail}`,
  );
}
