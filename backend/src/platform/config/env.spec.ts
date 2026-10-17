import { EnvValidationError, loadEnv } from './env.js';

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

  it('rejects SMS_PROVIDER=mock in production', () => {
    expect(() =>
      loadEnv({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'production-secret',
        SMS_PROVIDER: 'mock',
      }),
    ).toThrow(/SMS_PROVIDER/);
  });

  it('rejects PUSH_PROVIDER=mock in production', () => {
    expect(() =>
      loadEnv({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'production-secret',
        SMS_PROVIDER: 'esms',
        PUSH_PROVIDER: 'mock',
      }),
    ).toThrow(/PUSH_PROVIDER/);
  });

  it('rejects VOICE_PROVIDER=mock in production', () => {
    expect(() =>
      loadEnv({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'production-secret',
        SMS_PROVIDER: 'esms',
        PUSH_PROVIDER: 'fcm',
        VOICE_PROVIDER: 'mock',
      }),
    ).toThrow(/VOICE_PROVIDER/);
  });

  it('defaults CONTACT_WINDOW_MINUTES to 120', () => {
    expect(loadEnv({}).CONTACT_WINDOW_MINUTES).toBe(120);
  });

  it('defaults ride fare bounds and offer TTL', () => {
    const env = loadEnv({});

    expect(env.RIDE_OFFER_TTL_SECONDS).toBe(60);
    expect(env.RIDE_MIN_FARE_VND).toBe(10_000);
    expect(env.RIDE_MAX_FARE_VND).toBe(500_000);
    expect(env.RIDE_REFERENCE_VND_PER_KM).toBe(8_000);
    expect(env.DRIVER_SEARCH_RADIUS_KM).toBe(5);
    expect(env.MAX_CONCURRENT_JOBS_PER_DRIVER).toBe(1);
    expect(env.PAYMENT_METHODS_ENABLED).toBe('["COD","SANDBOX"]');
    expect(env.DISPATCH_FALLBACK_LIMIT).toBe(20);
    expect(env.OTP_THROTTLE_LIMIT).toBe(10);
  });

  it('rejects a minimum fare above the maximum', () => {
    expect(() => loadEnv({ RIDE_MIN_FARE_VND: '20', RIDE_MAX_FARE_VND: '10' })).toThrow(
      EnvValidationError,
    );
  });

  it('rejects missing PAYMENT_PROVIDER in production', () => {
    expect(() =>
      loadEnv({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'production-secret',
        SMS_PROVIDER: 'esms',
        PUSH_PROVIDER: 'fcm',
      }),
    ).toThrow(/PAYMENT_PROVIDER/);
  });

  it('rejects PAYMENT_PROVIDER=sandbox in production', () => {
    expect(() =>
      loadEnv({
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'production-secret',
        SMS_PROVIDER: 'esms',
        PUSH_PROVIDER: 'fcm',
        PAYMENT_PROVIDER: 'sandbox',
      }),
    ).toThrow(/PAYMENT_PROVIDER/);
  });

  it('accepts a production secret with valid production providers', () => {
    const env = loadEnv({
      NODE_ENV: 'production',
      JWT_ACCESS_SECRET: 'production-secret',
      SMS_PROVIDER: 'esms',
      PUSH_PROVIDER: 'fcm',
      PAYMENT_PROVIDER: 'vnpay',
    });

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
    expect(env.SMTP_URL).toBe('smtp://bot%40example.com:secret@smtp.example.com:587');
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
