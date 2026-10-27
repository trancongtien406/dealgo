/**
 * Provider-neutral SMS failure. `reason` is stable for API mapping and metrics;
 * provider codes are kept for logs (never the message body or OTP).
 */
export type SmsFailureReason =
  | 'not_configured'
  | 'auth_failed'
  | 'invalid_phone'
  | 'brandname_or_template'
  | 'insufficient_balance'
  | 'rate_limited'
  | 'provider_unavailable'
  | 'rejected';

export class SmsDeliveryError extends Error {
  constructor(
    readonly reason: SmsFailureReason,
    readonly provider: string,
    readonly providerCode?: string,
  ) {
    super(`SMS ${provider} failed: ${reason}${providerCode ? ` (code ${providerCode})` : ''}`);
    this.name = 'SmsDeliveryError';
  }
}

/** Default OTP text without diacritics (GSM-7, 1 segment). Must match the carrier-registered template. */
export const DEFAULT_SMS_OTP_TEMPLATE =
  'Ma xac thuc DealGo cua ban la {code}. Ma co hieu luc trong {minutes} phut. Khong chia se ma nay voi bat ky ai.';

export function renderOtpMessage(template: string | undefined, code: string, minutes: number): string {
  return (template?.trim() || DEFAULT_SMS_OTP_TEMPLATE)
    .replaceAll('{code}', code)
    .replaceAll('{minutes}', String(minutes));
}

/** E.164 (+84…) → provider form 84… (digits only). Local 0xxxxxxxxx → 84xxxxxxxxx. */
export function toProviderMsisdn(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  if (digits.startsWith('0')) {
    return `84${digits.slice(1)}`;
  }
  return digits;
}
