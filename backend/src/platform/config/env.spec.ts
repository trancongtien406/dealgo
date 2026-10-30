import { PROD_ENV_OK } from '../../../test/fixtures/prod-env.js';
import { generateKeyPairSync } from 'node:crypto';
import { EnvValidationError, loadEnv } from './env.js';

const PROD_OK = PROD_ENV_OK;
const VNPAY = {
  VNPAY_TMN_CODE: 'T',
  VNPAY_HASH_SECRET: 'H',
  VNPAY_URL: 'https://sandbox.vnpayment.vn/x',
};

describe('loadEnv', () => {
  it('defaults PORT to 3001 and allows the development JWT secret and SMS mock', () => {
    const env = loadEnv({
      JWT_ACCESS_SECRET: 'dev-only-change-me',
      SMS_PROVIDER: 'mock',
    });

    expect(env.NODE_ENV).toBe('development');
    expect(env.PORT).toBe(3001);
    expect(env.JWT_ACCESS_SECRET).toBe('dev-only-change-me');
    expect(env.SMS_PROVIDER).toBe('mock');
  });

  it('reads an explicit port', () => {
    expect(loadEnv({ PORT: '3010' }).PORT).toBe(3010);
  });

  it('rejects a missing JWT secret in production', () => {
    expect(() =>
      loadEnv({
        NODE_ENV: 'production',
        SMS_PROVIDER: 'esms',
      }),
    ).toThrow(EnvValidationError);
    expect(() =>
      loadEnv({
        NODE_ENV: 'production',
        SMS_PROVIDER: 'esms',
      }),
    ).toThrow(/JWT_ACCESS_SECRET/);
  });

  it('rejects the development JWT secret in production', () => {
    expect(() =>
      loadEnv({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'dev-only-change-me',
        SMS_PROVIDER: 'esms',
      }),
    ).toThrow(/JWT_ACCESS_SECRET/);
  });

  it('rejects a missing CHAT_ENCRYPTION_KEY in production', () => {
    expect(() =>
      loadEnv({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'production-secret',
      }),
    ).toThrow(/CHAT_ENCRYPTION_KEY/);
  });

  it('rejects SMS_PROVIDER=mock in production', () => {
    expect(() => loadEnv({ ...PROD_OK, SMS_PROVIDER: 'mock' })).toThrow(
      /SMS_PROVIDER/,
    );
  });

  it('rejects PUSH_PROVIDER=mock in production', () => {
    expect(() => loadEnv({ ...PROD_OK, PUSH_PROVIDER: 'mock' })).toThrow(
      /PUSH_PROVIDER/,
    );
  });

  it('rejects PUSH_PROVIDER=fcm without credentials in production', () => {
    expect(() => loadEnv({ ...PROD_OK, FCM_PRIVATE_KEY: undefined })).toThrow(
      /FCM_PROJECT_ID/,
    );
  });

  it('validates the LiveKit voice config', () => {
    const secret = 'x'.repeat(32);
    expect(() => loadEnv({ ...PROD_OK, VOICE_PROVIDER: 'twilio' })).toThrow(
      /VOICE_PROVIDER/,
    );
    expect(() => loadEnv({ ...PROD_OK, VOICE_PROVIDER: 'livekit' })).toThrow(
      /LIVEKIT_URL/,
    );
    expect(() => loadEnv({ ...PROD_OK, LIVEKIT_API_KEY: 'k' })).toThrow(
      /set together/,
    );
    expect(() =>
      loadEnv({
        ...PROD_OK,
        VOICE_PROVIDER: 'livekit',
        LIVEKIT_URL: 'ws://lk.example',
        LIVEKIT_API_KEY: 'k',
        LIVEKIT_API_SECRET: secret,
      }),
    ).toThrow(/LIVEKIT_URL must use wss:\/\/ when NODE_ENV=production/);
    expect(() =>
      loadEnv({
        ...PROD_OK,
        VOICE_PROVIDER: 'livekit',
        LIVEKIT_URL: 'https://lk.example',
        LIVEKIT_API_KEY: 'k',
        LIVEKIT_API_SECRET: secret,
      }),
    ).toThrow(/ws:\/\/ or wss:\/\//);
    expect(() =>
      loadEnv({
        ...PROD_OK,
        VOICE_PROVIDER: 'livekit',
        LIVEKIT_URL: 'wss://lk.example',
        LIVEKIT_API_KEY: 'k',
        LIVEKIT_API_SECRET: 'short',
      }),
    ).toThrow(/32 characters/);
    expect(
      loadEnv({
        ...PROD_OK,
        VOICE_PROVIDER: 'livekit',
        LIVEKIT_URL: 'wss://lk.example',
        LIVEKIT_API_KEY: 'k',
        LIVEKIT_API_SECRET: secret,
      }).VOICE_PROVIDER,
    ).toBe('livekit');
    // Dev keeps plain ws:// to the local docker LiveKit (LAN IP).
    expect(
      loadEnv({
        VOICE_PROVIDER: 'livekit',
        LIVEKIT_URL: 'ws://192.168.1.10:7880',
        LIVEKIT_API_KEY: 'devkey',
        LIVEKIT_API_SECRET: 'secret',
      }).LIVEKIT_URL,
    ).toBe('ws://192.168.1.10:7880');
    // Calls stay off (VOICE_UNAVAILABLE at runtime) when no provider is configured.
    expect(loadEnv({ ...PROD_OK }).VOICE_PROVIDER).toBeUndefined();
  });

  it('rejects VOICE_PROVIDER=mock in production', () => {
    expect(() => loadEnv({ ...PROD_OK, VOICE_PROVIDER: 'mock' })).toThrow(
      /VOICE_PROVIDER/,
    );
  });

  it('defaults CONTACT_WINDOW_MINUTES to 120', () => {
    expect(loadEnv({}).CONTACT_WINDOW_MINUTES).toBe(120);
  });

  it('defaults ride fare bounds and offer TTL', () => {
    const env = loadEnv({});

    expect(env.RIDE_OFFER_TTL_SECONDS).toBe(60);
    expect(env.RIDE_MIN_FARE_VND).toBe(10_000);
    expect(env.RIDE_MAX_FARE_VND).toBe(500_000);
    expect(env.RIDE_REFERENCE_VND_PER_KM).toBe(5_000);
    expect(env.DRIVER_SEARCH_RADIUS_KM).toBe(5);
    expect(env.MAX_CONCURRENT_JOBS_PER_DRIVER).toBe(1);
    expect((env as Record<string, unknown>).PAYMENT_METHODS_ENABLED).toBeUndefined();
    expect(env.DISPATCH_FALLBACK_LIMIT).toBe(20);
    expect(env.OTP_THROTTLE_LIMIT).toBe(10);
  });

  it('rejects a minimum fare above the maximum', () => {
    expect(() =>
      loadEnv({ RIDE_MIN_FARE_VND: '20', RIDE_MAX_FARE_VND: '10' }),
    ).toThrow(EnvValidationError);
  });

  it('rejects missing PAYMENT_PROVIDER in production', () => {
    expect(() => loadEnv({ ...PROD_OK, PAYMENT_PROVIDER: undefined })).toThrow(
      /PAYMENT_PROVIDER/,
    );
  });

  it('rejects PAYMENT_PROVIDER=sandbox in production', () => {
    expect(() => loadEnv({ ...PROD_OK, PAYMENT_PROVIDER: 'sandbox' })).toThrow(
      /PAYMENT_PROVIDER/,
    );
  });

  it('accepts a production secret with valid production providers', () => {
    const env = loadEnv({ ...PROD_OK, PAYMENT_PROVIDER: 'vnpay', ...VNPAY });

    expect(env.PORT).toBe(3001);
    expect(env.JWT_ACCESS_SECRET).toBe('production-secret');
    expect(env.SMS_PROVIDER).toBe('esms');
    expect(env.PUSH_PROVIDER).toBe('fcm');
    expect(env.PAYMENT_PROVIDER).toBe('vnpay');
  });

  it('maps JWT_SECRET to JWT_ACCESS_SECRET when the latter is unset', () => {
    const env = loadEnv({ JWT_SECRET: 'legacy-local-secret' });
    expect(env.JWT_ACCESS_SECRET).toBe('legacy-local-secret');
  });

  it('keeps JWT_ACCESS_SECRET when both JWT secrets are set', () => {
    const env = loadEnv({
      JWT_ACCESS_SECRET: 'canonical',
      JWT_SECRET: 'legacy',
    });
    expect(env.JWT_ACCESS_SECRET).toBe('canonical');
  });

  it('maps fake provider aliases used in local .env files', () => {
    const env = loadEnv({
      SMS_PROVIDER: 'fake',
      EMAIL_PROVIDER: 'fake',
      PAYMENT_PROVIDER: 'fake',
    });
    expect(env.SMS_PROVIDER).toBe('mock');
    expect(env.EMAIL_PROVIDER).toBe('mock');
    expect(env.PAYMENT_PROVIDER).toBe('sandbox');
  });

  it('maps S3_BUCKET_NAME and S3_API_ENDPOINT aliases', () => {
    const env = loadEnv({
      S3_BUCKET_NAME: 'dealgo-kyc',
      S3_API_ENDPOINT: 'https://example.r2.cloudflarestorage.com',
    });
    expect(env.S3_BUCKET).toBe('dealgo-kyc');
    expect(env.S3_ENDPOINT).toBe('https://example.r2.cloudflarestorage.com');
  });

  it('builds SMTP_URL from discrete SMTP_* vars when SMTP_URL is unset', () => {
    const env = loadEnv({
      SMTP_HOST: 'smtp.example.com',
      SMTP_PORT: '587',
      SMTP_USER: 'bot@example.com',
      SMTP_PASSWORD: 'secret',
    });
    expect(env.SMTP_URL).toBe(
      'smtp://bot%40example.com:secret@smtp.example.com:587',
    );
  });

  it('keeps an explicit SMTP_URL over discrete SMTP_* vars', () => {
    const env = loadEnv({
      SMTP_URL: 'smtp://keep-me.example:2525',
      SMTP_HOST: 'ignored.example.com',
      SMTP_PORT: '587',
    });
    expect(env.SMTP_URL).toBe('smtp://keep-me.example:2525');
  });

  it('accepts FCM service-account path keys without requiring FCM_* PEM fields', () => {
    const env = loadEnv({
      PUSH_PROVIDER: 'fcm',
      FCM_SERVICE_ACCOUNT_PATH: './service-account.json',
      GOOGLE_APPLICATION_CREDENTIALS: './alt.json',
    });
    expect(env.FCM_SERVICE_ACCOUNT_PATH).toBe('./service-account.json');
    expect(env.GOOGLE_APPLICATION_CREDENTIALS).toBe('./alt.json');
  });
});

describe('loadEnv production fail-safes (DEC-PROD-050/051)', () => {
  it('accepts the complete production env and an explicit cash-only launch', () => {
    const env = loadEnv(PROD_OK);
    expect(env.PAYMENT_PROVIDER).toBe('cash-only');
    // The admin setting default becomes ["COD"] for cash-only (platform-settings.service).
  });

  it.each(['none', 'cash', 'COD'])(
    'normalizes PAYMENT_PROVIDER=%s to cash-only',
    (value) => {
      expect(
        loadEnv({ ...PROD_OK, PAYMENT_PROVIDER: value }).PAYMENT_PROVIDER,
      ).toBe('cash-only');
    },
  );

  it('allows SMS and email to be unset (method disabled) but rejects a chosen provider without keys', () => {
    expect(() =>
      loadEnv({ ...PROD_OK, SMS_PROVIDER: undefined, EMAIL_PROVIDER: 'none' }),
    ).not.toThrow();
    expect(() => loadEnv({ ...PROD_OK, ESMS_SECRET_KEY: undefined })).toThrow(
      /ESMS_API_KEY/,
    );
    expect(() => loadEnv({ ...PROD_OK, ESMS_SANDBOX: 'true' })).toThrow(
      /ESMS_SANDBOX/,
    );
    expect(() => loadEnv({ ...PROD_OK, SMS_PROVIDER: 'speedsms' })).toThrow(
      /SPEEDSMS/,
    );
    expect(() =>
      loadEnv({
        ...PROD_OK,
        SMS_PROVIDER: 'speedsms',
        SPEEDSMS_ACCESS_TOKEN: 't',
      }),
    ).not.toThrow();
    expect(() =>
      loadEnv({ ...PROD_OK, SES_SECRET_ACCESS_KEY: undefined }),
    ).toThrow(/SES_REGION/);
    expect(() => loadEnv({ ...PROD_OK, EMAIL_PROVIDER: 'mock' })).toThrow(
      /EMAIL_PROVIDER=mock/,
    );
    expect(() => loadEnv({ ...PROD_OK, EMAIL_PROVIDER: 'smtp' })).toThrow(
      /SMTP_URL/,
    );
  });

  it('refuses disabled maps/routing or a missing Mapbox token', () => {
    expect(() => loadEnv({ ...PROD_OK, MAPS_PROVIDER: 'none' })).toThrow(
      /MAPS_PROVIDER/,
    );
    expect(() =>
      loadEnv({
        ...PROD_OK,
        MAPBOX_ACCESS_TOKEN: undefined,
        MAPBOX_DIRECTIONS_TOKEN: undefined,
      }),
    ).toThrow(/MAPS_PROVIDER=mapbox/);
    expect(() => loadEnv({ ...PROD_OK, ROUTING_PROVIDER: 'none' })).toThrow(
      /ROUTING_PROVIDER/,
    );
    expect(() =>
      loadEnv({ ...PROD_OK, MAPBOX_DIRECTIONS_TOKEN: undefined }),
    ).toThrow(/MAPBOX_DIRECTIONS_TOKEN/);
  });

  it('validates CHAT_ENCRYPTION_KEY length in every environment', () => {
    const short = Buffer.alloc(19, 1).toString('base64');
    expect(() => loadEnv({ CHAT_ENCRYPTION_KEY: short })).toThrow(/32 bytes/);
    expect(() =>
      loadEnv({ NODE_ENV: 'test', CHAT_ENCRYPTION_KEY: short }),
    ).toThrow(/32 bytes/);
    expect(() =>
      loadEnv({ CHAT_ENCRYPTION_PREVIOUS_KEYS: `1:${short}` }),
    ).toThrow(EnvValidationError);
    expect(
      loadEnv({ CHAT_ENCRYPTION_KEY: Buffer.alloc(32, 2).toString('base64') })
        .CHAT_ENCRYPTION_KEY,
    ).toBeTruthy();
  });

  it('requires APP_REVIEW_OTP_CODE to be 6 digits when set', () => {
    expect(() => loadEnv({ APP_REVIEW_OTP_CODE: '12ab' })).toThrow(
      /APP_REVIEW_OTP_CODE/,
    );
    expect(loadEnv({ APP_REVIEW_OTP_CODE: '246810' }).APP_REVIEW_OTP_CODE).toBe(
      '246810',
    );
  });
});

describe('loadEnv production APNs VoIP key', () => {
  const p8 = generateKeyPairSync('ec', { namedCurve: 'P-256' })
    .privateKey.export({ format: 'pem', type: 'pkcs8' })
    .toString()
    .replace(/\n/g, '\\n');
  const ids = { APNS_KEY_ID: 'TL36K38ZKR', APNS_TEAM_ID: '6J3522877H' };

  it('boots without APNs (calls ring via FCM) and with only the non-secret ids prefilled', () => {
    expect(() => loadEnv(PROD_OK)).not.toThrow();
    expect(() =>
      loadEnv({ ...PROD_OK, ...ids, APNS_KEY_PATH: '' }),
    ).not.toThrow();
  });

  it('boots with a complete key and fails fast on a half-done setup', () => {
    expect(() =>
      loadEnv({ ...PROD_OK, ...ids, APNS_PRIVATE_KEY: p8 }),
    ).not.toThrow();
    expect(() =>
      loadEnv({ ...PROD_OK, ...ids, APNS_KEY_PATH: '/nonexistent/AuthKey.p8' }),
    ).toThrow(/APNs key file not readable/);
    expect(() =>
      loadEnv({ ...PROD_OK, APNS_KEY_ID: 'TL36K38ZKR', APNS_PRIVATE_KEY: p8 }),
    ).toThrow(/APNS_TEAM_ID/);
    expect(() =>
      loadEnv({ ...PROD_OK, ...ids, APNS_PRIVATE_KEY: 'not-a-key' }),
    ).toThrow(/valid \.p8/);
    expect(() =>
      loadEnv({ ...PROD_OK, ...ids, APNS_PRIVATE_KEY: p8, APNS_ENV: 'prod' }),
    ).toThrow(/APNS_ENV/);
  });
});
