import type { AppEnv } from '../../platform/config/env.js';
import { EsmsSmsSender } from './esms-sms-sender.js';
import { MockSmsSender, UnavailableSmsSender, type SmsSender } from './sms-sender.js';
import { SpeedSmsSender } from './speedsms-sms-sender.js';

export type SmsEnv = Pick<
  AppEnv,
  | 'NODE_ENV'
  | 'SMS_PROVIDER'
  | 'ESMS_API_KEY'
  | 'ESMS_SECRET_KEY'
  | 'ESMS_BRANDNAME'
  | 'ESMS_SMS_TYPE'
  | 'ESMS_SANDBOX'
  | 'ESMS_BASE_URL'
  | 'SPEEDSMS_ACCESS_TOKEN'
  | 'SPEEDSMS_SENDER'
  | 'SPEEDSMS_SMS_TYPE'
  | 'SPEEDSMS_BASE_URL'
  | 'SMS_OTP_TEMPLATE'
  | 'SMS_HTTP_TIMEOUT_MS'
  | 'SMS_HTTP_MAX_ATTEMPTS'
>;

/**
 * SMS_PROVIDER → adapter. Unset/mock = mock outside production; `none`, unknown or missing keys =
 * Unavailable (the PHONE_SMS auth method then cannot be enabled — see AuthMethodProviderCheck).
 */
export function createSmsSender(env: SmsEnv, ttlMinutes: number): SmsSender {
  const provider = env.SMS_PROVIDER;
  if ((provider === 'mock' || provider === undefined) && env.NODE_ENV !== 'production') {
    return new MockSmsSender(env.NODE_ENV);
  }
  const common = {
    template: env.SMS_OTP_TEMPLATE,
    ttlMinutes,
    timeoutMs: env.SMS_HTTP_TIMEOUT_MS,
    maxAttempts: env.SMS_HTTP_MAX_ATTEMPTS,
  };
  if (provider === 'esms' && env.ESMS_API_KEY && env.ESMS_SECRET_KEY && env.ESMS_BRANDNAME) {
    return new EsmsSmsSender({
      ...common,
      apiKey: env.ESMS_API_KEY,
      secretKey: env.ESMS_SECRET_KEY,
      brandname: env.ESMS_BRANDNAME,
      smsType: env.ESMS_SMS_TYPE,
      sandbox: env.NODE_ENV !== 'production' && env.ESMS_SANDBOX === true,
      baseUrl: env.ESMS_BASE_URL,
    });
  }
  if (provider === 'speedsms' && env.SPEEDSMS_ACCESS_TOKEN) {
    return new SpeedSmsSender({
      ...common,
      accessToken: env.SPEEDSMS_ACCESS_TOKEN,
      sender: env.SPEEDSMS_SENDER,
      smsType: env.SPEEDSMS_SMS_TYPE,
      baseUrl: env.SPEEDSMS_BASE_URL,
    });
  }
  return new UnavailableSmsSender();
}

export function isSmsSenderAvailable(sender: SmsSender): boolean {
  return !(sender instanceof UnavailableSmsSender);
}
