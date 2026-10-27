import { describe, expect, it, vi } from 'vitest';
import { EsmsSmsSender, mapEsmsCode } from './esms-sms-sender.js';
import { createSmsSender, isSmsSenderAvailable, type SmsEnv } from './sms-factory.js';
import { SmsDeliveryError } from './sms-errors.js';
import { MockSmsSender } from './sms-sender.js';
import { SpeedSmsSender, mapSpeedSmsCode } from './speedsms-sms-sender.js';

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
const common = { ttlMinutes: 5, timeoutMs: 1_000, maxAttempts: 2, backoffMs: 0 };

describe('EsmsSmsSender', () => {
  const config = { ...common, apiKey: 'ak', secretKey: 'sk', brandname: 'DealGo' };

  it('posts an OTP in 84… format with brandname SmsType 2 and accepts CodeResult 100', async () => {
    const fetchImpl = vi.fn(async (_url: string, _init: RequestInit) => json({ CodeResult: '100', SMSID: 'x' }));
    await new EsmsSmsSender(config, fetchImpl).sendOtp('+84901234567', '123456');
    const [url, init] = fetchImpl.mock.calls[0]!;
    expect(url).toBe('https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json/');
    const body = JSON.parse(init.body as string);
    expect(body).toMatchObject({ Phone: '84901234567', Brandname: 'DealGo', SmsType: '2', Sandbox: '0' });
    expect(body.Content).toContain('123456');
    expect(body.RequestId).toEqual(expect.any(String));
  });

  it('maps provider rejections to neutral reasons', async () => {
    const fetchImpl = vi.fn(async () => json({ CodeResult: '99', ErrorMessage: 'x' }));
    const error = await new EsmsSmsSender(config, fetchImpl).sendOtp('+84901234567', '1').catch((e) => e);
    expect(error).toBeInstanceOf(SmsDeliveryError);
    expect(error.provider).toBe('esms');
    expect(mapEsmsCode('101')).toBe('auth_failed');
    expect(mapEsmsCode('103')).toBe('insufficient_balance');
  });

  it('turns transport failures into provider_unavailable', async () => {
    const fetchImpl = vi.fn(async () => new Response('down', { status: 502 }));
    await expect(new EsmsSmsSender(config, fetchImpl).sendOtp('+84901234567', '1')).rejects.toMatchObject({
      reason: 'provider_unavailable',
    });
  });
});

describe('SpeedSmsSender', () => {
  it('uses Basic auth and the shared "Verify" sender (type 4) without a brandname', async () => {
    const fetchImpl = vi.fn(async (_url: string, _init: RequestInit) => json({ status: 'success', code: '00' }));
    await new SpeedSmsSender({ ...common, accessToken: 'tok' }, fetchImpl).sendOtp('0901234567', '654321');
    const [url, init] = fetchImpl.mock.calls[0]!;
    expect(url).toBe('https://api.speedsms.vn/index.php/sms/send');
    expect((init.headers as Record<string, string>).authorization).toBe(
      `Basic ${Buffer.from('tok:x').toString('base64')}`,
    );
    const body = JSON.parse(init.body as string);
    expect(body.to).toEqual(['84901234567']);
    expect(String(body.sms_type)).toBe('4');
  });

  it('rejects error responses with a mapped reason', async () => {
    const fetchImpl = vi.fn(async () => json({ status: 'error', code: '007' }));
    await expect(new SpeedSmsSender({ ...common, accessToken: 'tok' }, fetchImpl).sendOtp('0901234567', '1')).rejects.toBeInstanceOf(
      SmsDeliveryError,
    );
    expect(mapSpeedSmsCode('unknown-code')).toEqual(expect.any(String));
  });
});

describe('createSmsSender', () => {
  const env = (patch: Partial<SmsEnv>): SmsEnv =>
    ({ NODE_ENV: 'development', SMS_HTTP_TIMEOUT_MS: 1000, SMS_HTTP_MAX_ATTEMPTS: 2, ...patch }) as SmsEnv;

  it('uses the mock outside production and nothing in production without a provider', () => {
    expect(createSmsSender(env({}), 5)).toBeInstanceOf(MockSmsSender);
    expect(isSmsSenderAvailable(createSmsSender(env({ NODE_ENV: 'production' }), 5))).toBe(false);
  });

  it('builds eSMS / SpeedSMS only when their keys are present', () => {
    expect(createSmsSender(env({ SMS_PROVIDER: 'esms' }), 5)).not.toBeInstanceOf(EsmsSmsSender);
    expect(
      createSmsSender(env({ SMS_PROVIDER: 'esms', ESMS_API_KEY: 'a', ESMS_SECRET_KEY: 'b', ESMS_BRANDNAME: 'c' }), 5),
    ).toBeInstanceOf(EsmsSmsSender);
    expect(createSmsSender(env({ SMS_PROVIDER: 'speedsms', SPEEDSMS_ACCESS_TOKEN: 't' }), 5)).toBeInstanceOf(
      SpeedSmsSender,
    );
  });
});
