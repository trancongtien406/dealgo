import { Logger } from '@nestjs/common';
import { redactPhone } from '../../modules/identity/phone-number.js';
import { ProviderHttpError, providerHttp, safeJson, type FetchLike } from '../http/provider-http.js';
import { renderOtpMessage, SmsDeliveryError, toProviderMsisdn, type SmsFailureReason } from './sms-errors.js';
import type { SmsSender } from './sms-sender.js';

export const SPEEDSMS_DEFAULT_BASE_URL = 'https://api.speedsms.vn/index.php';

export type SpeedSmsConfig = {
  accessToken: string;
  /** Registered brandname (sms_type 3). Unset → shared default brandname "Verify" (sms_type 4). */
  sender?: string;
  smsType?: string;
  baseUrl?: string;
  template?: string;
  ttlMinutes: number;
  timeoutMs: number;
  maxAttempts: number;
  backoffMs?: number;
};

/**
 * SpeedSMS.vn (DEC-PROD-050, secondary). Useful before an own brandname is approved: sms_type 4
 * sends from the shared "Verify" brandname with no carrier registration. Auth = HTTP Basic token:x.
 * SpeedSMS has no idempotency key, so only transport failures before a response are retried.
 */
export class SpeedSmsSender implements SmsSender {
  private readonly logger = new Logger(SpeedSmsSender.name);

  constructor(
    private readonly config: SpeedSmsConfig,
    private readonly fetchImpl: FetchLike = fetch,
  ) {}

  async sendOtp(phone: string, code: string): Promise<void> {
    const sender = this.config.sender?.trim() || 'Verify';
    const smsType = Number(this.config.smsType ?? (this.config.sender?.trim() ? '3' : '4'));
    let response;
    try {
      response = await providerHttp(
        {
          url: `${(this.config.baseUrl ?? SPEEDSMS_DEFAULT_BASE_URL).replace(/\/+$/, '')}/sms/send`,
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            accept: 'application/json',
            authorization: `Basic ${Buffer.from(`${this.config.accessToken}:x`).toString('base64')}`,
          },
          body: JSON.stringify({
            to: [toProviderMsisdn(phone)],
            content: renderOtpMessage(this.config.template, code, this.config.ttlMinutes),
            sms_type: smsType,
            sender,
          }),
          timeoutMs: this.config.timeoutMs,
          maxAttempts: this.config.maxAttempts,
          backoffMs: this.config.backoffMs,
        },
        this.fetchImpl,
      );
    } catch (error) {
      this.logger.warn({ msg: 'sms.speedsms.transport_failed', phone: redactPhone(phone), error: (error as Error).message });
      throw new SmsDeliveryError(
        error instanceof ProviderHttpError && error.status === 429 ? 'rate_limited' : 'provider_unavailable',
        'speedsms',
      );
    }
    const json = safeJson(response.text);
    if (response.status === 401 || response.status === 403) {
      throw new SmsDeliveryError('auth_failed', 'speedsms', `http_${response.status}`);
    }
    const status = json?.status;
    const code_ = scalarText(json?.code, `http_${response.status}`);
    if (status === 'success' && code_ === '00') {
      const data = (json?.data ?? {}) as { tranId?: unknown; invalidPhone?: unknown };
      if (Array.isArray(data.invalidPhone) && data.invalidPhone.length > 0) {
        throw new SmsDeliveryError('invalid_phone', 'speedsms', '105');
      }
      this.logger.log({ msg: 'sms.speedsms.sent', phone: redactPhone(phone), tranId: data.tranId });
      return;
    }
    this.logger.warn({ msg: 'sms.speedsms.rejected', phone: redactPhone(phone), code: code_ });
    throw new SmsDeliveryError(mapSpeedSmsCode(code_), 'speedsms', code_);
  }
}

/** Documented SpeedSMS error codes → provider-neutral reasons. */
export function mapSpeedSmsCode(code: string): SmsFailureReason {
  switch (code) {
    case '007':
    case '008':
    case '009':
      return 'auth_failed';
    case '105':
      return 'invalid_phone';
    case '110':
    case '113':
      return 'brandname_or_template';
    case '300':
      return 'insufficient_balance';
    case '500':
      return 'provider_unavailable';
    default:
      return 'rejected';
  }
}

/** Provider codes are strings or numbers; anything else falls back. */
function scalarText(value: unknown, fallback: string): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : fallback;
}
