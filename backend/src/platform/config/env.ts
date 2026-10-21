import { z } from 'zod';

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
  (value) => (value === undefined || value === null || value === '' ? undefined : value),
  z.coerce.number().int().positive().optional(),
);

const positiveInt = (defaultValue: number) =>
  z.preprocess(
    (value) => (value === undefined || value === null || value === '' ? undefined : value),
    z.coerce.number().int().positive().default(defaultValue),
  );

const fareVnd = (defaultValue: number) =>
  z.preprocess(
    (value) => (value === undefined || value === null || value === '' ? undefined : value),
    z.coerce.number().int().positive().max(2_147_483_647).default(defaultValue),
  );

const optionalBoolean = z.preprocess(
  (value) => {
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
  },
  z.boolean().optional(),
);

const envSchema = z.object({
  NODE_ENV: z.preprocess(
    (value) => (value === undefined || value === null || value === '' ? undefined : value),
    z.enum(['development', 'test', 'production']).default('development'),
  ),
  PORT: positiveInt(3001),
  DATABASE_URL: optionalString,
  DATABASE_POOL_MAX: positiveInt(10),
  REDIS_URL: optionalString,
  JWT_ACCESS_SECRET: optionalString,
  // Access default 1h; refresh remains ~14d. Ops Admin BFF also refreshes on 401.
  JWT_ACCESS_TTL_SECONDS: positiveInt(3_600),
  JWT_REFRESH_TTL_SECONDS: positiveInt(1_209_600),
  WEBAUTHN_RP_ID: optionalString,
  WEBAUTHN_RP_NAME: optionalString,
  WEBAUTHN_ORIGIN: optionalString,
  /** Public website origin for share links (DEC-PROD-021), e.g. https://dealgo.vn. */
  PUBLIC_WEB_BASE_URL: optionalString,
  MAPS_PROVIDER: optionalString,
  /** DEC-PROD-045: Admin map road geometry — none (default, straight line) | osrm | mapbox. */
  ROUTING_PROVIDER: optionalString,
  /** Self-hosted OSRM base URL (no trailing path), e.g. http://osrm:5000. */
  ROUTING_OSRM_URL: optionalString,
  /** Server-side Mapbox Directions token (never sent to browsers). */
  MAPBOX_DIRECTIONS_TOKEN: optionalString,
  ROUTING_TIMEOUT_MS: positiveInt(4_000),
  GOONG_API_KEY: optionalString,
  GOOGLE_MAPS_API_KEY: optionalString,
  SMS_PROVIDER: optionalString,
  ESMS_API_KEY: optionalString,
  ESMS_SECRET_KEY: optionalString,
  ESMS_BRANDNAME: optionalString,
  TWILIO_ACCOUNT_SID: optionalString,
  TWILIO_AUTH_TOKEN: optionalString,
  TWILIO_FROM_NUMBER: optionalString,
  EMAIL_PROVIDER: optionalString,
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
  PAYMENT_PROVIDER: optionalString,
  VNPAY_TMN_CODE: optionalString,
  VNPAY_HASH_SECRET: optionalString,
  VNPAY_URL: optionalString,
  MOMO_PARTNER_CODE: optionalString,
  MOMO_ACCESS_KEY: optionalString,
  MOMO_SECRET_KEY: optionalString,
  MOMO_ENDPOINT: optionalString,
  VOICE_PROVIDER: optionalString,
  LIVEKIT_URL: optionalString,
  LIVEKIT_API_KEY: optionalString,
  LIVEKIT_API_SECRET: optionalString,
  // Contact window in minutes for chat and voice communication after terminal status.
  CONTACT_WINDOW_MINUTES: positiveInt(120),
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
  RIDE_OFFER_TTL_SECONDS: positiveInt(60),
  RIDE_NEGOTIATION_MAX_ROUNDS: optionalPositiveInt,
  RIDE_MIN_FARE_VND: fareVnd(10_000),
  RIDE_MAX_FARE_VND: fareVnd(500_000),
  RIDE_REFERENCE_VND_PER_KM: fareVnd(8_000),
  FOOD_MIN_DELIVERY_VND: fareVnd(5_000),
  FOOD_MAX_DELIVERY_VND: fareVnd(100_000),
  // Per-km delivery quote; clamped by FOOD_MIN/MAX after distance.
  FOOD_DELIVERY_VND_PER_KM: fareVnd(3_000),
  // Driver search radius in km for dispatch queries.
  DRIVER_SEARCH_RADIUS_KM: z.preprocess(
    (value) => (value === undefined || value === null || value === '' ? undefined : value),
    z.coerce.number().positive().max(100).default(5),
  ),
  // Maximum concurrent active jobs per driver — enforced on food claim + ride select.
  MAX_CONCURRENT_JOBS_PER_DRIVER: positiveInt(1),
  // OPEN-002 channel flags (not PSP secrets). JSON array string.
  PAYMENT_METHODS_ENABLED: z.preprocess(
    (value) => (value === undefined || value === null || value === '' ? undefined : value),
    z
      .string()
      .default('["COD","SANDBOX"]')
      .refine((raw) => {
        try {
          const parsed: unknown = JSON.parse(raw);
          return Array.isArray(parsed) && parsed.every((x) => typeof x === 'string');
        } catch {
          return false;
        }
      }, 'PAYMENT_METHODS_ENABLED must be a JSON array of strings'),
  ),
  // Cap when driver omits lat/lng so open/ready lists stay bounded.
  DISPATCH_FALLBACK_LIMIT: positiveInt(20),
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
  // Defaults: true outside production; false in production unless explicitly set.
  PARTNER_ELIGIBILITY_BYPASS: optionalBoolean,
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

  assertProductionProviders(parsed.data);
  if (parsed.data.RIDE_MIN_FARE_VND > parsed.data.RIDE_MAX_FARE_VND) {
    throw new EnvValidationError('RIDE_MIN_FARE_VND must not exceed RIDE_MAX_FARE_VND');
  }
  if (parsed.data.FOOD_MIN_DELIVERY_VND > parsed.data.FOOD_MAX_DELIVERY_VND) {
    throw new EnvValidationError('FOOD_MIN_DELIVERY_VND must not exceed FOOD_MAX_DELIVERY_VND');
  }
  return parsed.data;
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
  });

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

function buildSmtpUrlFromDiscrete(source: Record<string, unknown>): string | undefined {
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
    tls === true ||
    tls === 'true' ||
    tls === '1' ||
    port === 465;
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

function assertProductionProviders(env: AppEnv): void {
  if (env.NODE_ENV !== 'production') {
    return;
  }

  if (!env.JWT_ACCESS_SECRET || env.JWT_ACCESS_SECRET === DEV_JWT_ACCESS_SECRET) {
    throw new EnvValidationError(
      'JWT_ACCESS_SECRET must be set to a non-development value when NODE_ENV=production',
    );
  }

  if (env.SMS_PROVIDER === 'mock') {
    throw new EnvValidationError(
      'SMS_PROVIDER=mock is not allowed when NODE_ENV=production',
    );
  }

  if (env.PUSH_PROVIDER === 'mock') {
    throw new EnvValidationError(
      'PUSH_PROVIDER=mock is not allowed when NODE_ENV=production',
    );
  }

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
      'PAYMENT_PROVIDER=sandbox is not allowed when NODE_ENV=production',
    );
  }
}
