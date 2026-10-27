import { randomUUID } from 'node:crypto';
import { Logger } from '@nestjs/common';
import { redactPhone } from '../../modules/identity/phone-number.js';
import { ProviderHttpError, providerHttp, safeJson, type FetchLike } from '../http/provider-http.js';
import { renderOtpMessage, SmsDeliveryError, toProviderMsisdn, type SmsFailureReason } from './sms-errors.js';
import type { SmsSender } from './sms-sender.js';

export const ESMS_DEFAULT_BASE_URL = 'https://rest.esms.vn/MainService.svc/json';

export type EsmsConfig = {
  apiKey: string;
  secretKey: string;
  brandname: string;
  /** eSMS SmsType; 2 = brandname CSKH (OTP). */
  smsType?: string;
  sandbox?: boolean;
  baseUrl?: string;
  template?: string;
  ttlMinutes: number;
  timeoutMs: number;
  maxAttempts: number;
  backoffMs?: number;
};

/**
 * eSMS.vn brandname OTP (DEC-PROD-050, primary). API: SendMultipleMessage_V4_post_json.
 * One RequestId per OTP is reused across retries: eSMS de-duplicates it for 24h, so a retry after a
 * timed-out-but-delivered first attempt returns 124 and is treated as delivered (no double charge).
 */
export class EsmsSmsSender implements SmsSender {
  private readonly logger = new Logger(EsmsSmsSender.name);

  constructor(
    private readonly config: EsmsConfig,
    private readonly fetchImpl: FetchLike = fetch,
  ) {}

  async sendOtp(phone: string, code: string): Promise<void> {
    const requestId = randomUUID();
    const body = {
      ApiKey: this.config.apiKey,
      SecretKey: this.config.secretKey,
      Phone: toProviderMsisdn(phone),
      Content: renderOtpMessage(this.config.template, code, this.config.ttlMinutes),
      Brandname: this.config.brandname,
      SmsType: this.config.smsType ?? '2',
      IsUnicode: '0',
      Sandbox: this.config.sandbox ? '1' : '0',
      RequestId: requestId,
    };
    let response;
    try {
      response = await providerHttp(
        {
          url: `${(this.config.baseUrl ?? ESMS_DEFAULT_BASE_URL).replace(/\/+$/, '')}/SendMultipleMessage_V4_post_json/`,
          method: 'POST',
          headers: { 'content-type': 'application/json', accept: 'application/json' },
          body: JSON.stringify(body),
          timeoutMs: this.config.timeoutMs,
          maxAttempts: this.config.maxAttempts,
          backoffMs: this.config.backoffMs,
        },
        this.fetchImpl,
      );
    } catch (error) {
      this.logger.warn({ msg: 'sms.esms.transport_failed', phone: redactPhone(phone), error: (error as Error).message });
      throw new SmsDeliveryError(
        error instanceof ProviderHttpError && error.status === 429 ? 'rate_limited' : 'provider_unavailable',
        'esms',
      );
    }
    const json = safeJson(response.text);
    const result = scalarText(json?.CodeResult, `http_${response.status}`);
    if (result === '100' || (result === '124' && response.attempt > 1)) {
      this.logger.log({ msg: 'sms.esms.sent', phone: redactPhone(phone), smsId: json?.SMSID, sandbox: !!this.config.sandbox });
      return;
    }
    this.logger.warn({ msg: 'sms.esms.rejected', phone: redactPhone(phone), code: result });
    throw new SmsDeliveryError(mapEsmsCode(result), 'esms', result);
  }
}

/** Documented eSMS CodeResult values → provider-neutral reasons. */
export function mapEsmsCode(code: string): SmsFailureReason {
  switch (code) {
    case '101':
      return 'auth_failed';
    case '102':
    case '103':
      return 'insufficient_balance';
    case '104':
    case '146':
    case '177':
      return 'brandname_or_template';
    case '118':
    case '119':
    case '131':
      return 'invalid_phone';
    case '124':
    case '145':
      return 'rate_limited';
    case '99':
      return 'provider_unavailable';
    default:
      return 'rejected';
  }
}

/** Provider codes are strings or numbers; anything else falls back. */
function scalarText(value: unknown, fallback: string): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : fallback;
}
