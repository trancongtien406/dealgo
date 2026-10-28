import type { PaymentProviderName } from '../../../modules/payment/payment.constants.js';

/** REAL = signs/calls the PSP per its official docs; STUB = placeholder, never selectable. */
export type PaymentAdapterKind = 'REAL' | 'STUB';

export type AdapterCreateRequest = {
  /** Our merchant order reference (unique per attempt, [A-Za-z0-9_]). */
  orderRef: string;
  amountVnd: number;
  orderInfo: string;
  /** Browser/app return after the PSP page. */
  returnUrl: string;
  /** Server-to-server IPN/callback. */
  ipnUrl: string;
  clientIp: string;
  userRef: string;
  /** Registry method code (e.g. VNPAY_ATM selects the ATM/Napas bank list). */
  methodCode: string;
  now: Date;
};

export type AdapterCreateResult = {
  providerRef: string;
  paymentUrl: string | null;
  deeplink: string | null;
};

export type AdapterCallback = {
  /** Signature/MAC verified with the merchant secret. */
  valid: boolean;
  providerRef: string | null;
  /** Stable id for idempotency (same retried callback => same id). */
  providerEventId: string | null;
  success: boolean;
  amountVnd: number | null;
  providerTransId: string | null;
  providerPayDate: string | null;
  failureReason: string | null;
};

export type AdapterRefundRequest = {
  providerRef: string;
  providerTransId: string | null;
  providerPayDate: string | null;
  amountVnd: number;
  capturedAmountVnd: number;
  reason: string;
  requestId: string;
  actorRef: string;
  clientIp: string;
  now: Date;
};

export type AdapterRefundResult = {
  status: 'ACCEPTED' | 'PENDING' | 'REJECTED';
  providerRefundRef: string | null;
  message: string | null;
};

export type AdapterQueryRequest = {
  providerRef: string;
  /** When the attempt was created (VNPay querydr needs the original vnp_CreateDate). */
  attemptedAt: Date;
  requestId: string;
  clientIp: string;
  now: Date;
};

/** Provider-side truth for one attempt (active reconciliation). */
export type AdapterQueryResult = {
  state: 'CAPTURED' | 'PENDING' | 'FAILED' | 'UNKNOWN';
  amountVnd: number | null;
  providerTransId: string | null;
  providerPayDate: string | null;
  message: string | null;
};

export type CallbackAckKind = 'OK' | 'INVALID_SIGNATURE' | 'NOT_FOUND' | 'AMOUNT_MISMATCH' | 'ALREADY' | 'ERROR';

export type CallbackAck = { httpStatus: number; body: unknown };

export interface PaymentAdapter {
  readonly provider: PaymentProviderName;
  readonly kind: PaymentAdapterKind;
  /** All required env keys present (values never exposed). */
  isConfigured(): boolean;
  /** Names of env keys this adapter needs (for ops status, no values). */
  requiredEnv(): readonly string[];
  create(request: AdapterCreateRequest): Promise<AdapterCreateResult>;
  verifyCallback(payload: Record<string, unknown>): AdapterCallback;
  ack(kind: CallbackAckKind): CallbackAck;
  refund(request: AdapterRefundRequest): Promise<AdapterRefundResult>;
  /** Status query API (MoMo query, ZaloPay query, VNPay querydr). */
  query(request: AdapterQueryRequest): Promise<AdapterQueryResult>;
}

export class PaymentAdapterError extends Error {
  constructor(
    readonly code: 'ADAPTER_NOT_CONFIGURED' | 'ADAPTER_STUB' | 'PSP_REJECTED' | 'PSP_UNREACHABLE',
    message: string,
  ) {
    super(message);
    this.name = 'PaymentAdapterError';
  }
}

export type HttpPost = (
  url: string,
  body: Record<string, unknown>,
  options: { form?: boolean; timeoutMs: number },
) => Promise<Record<string, unknown>>;

/** Default transport: fetch with a hard timeout. Tests inject a fake. */
export const fetchHttpPost: HttpPost = async (url, body, options) => {
  let response: Response;
  try {
    response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': options.form
          ? 'application/x-www-form-urlencoded'
          : 'application/json; charset=UTF-8',
      },
      body: options.form
        ? new URLSearchParams(
            Object.entries(body).map(([k, v]) => [k, v === undefined || v === null ? '' : String(v)]),
          ).toString()
        : JSON.stringify(body),
      signal: AbortSignal.timeout(options.timeoutMs),
    });
  } catch (error) {
    throw new PaymentAdapterError(
      'PSP_UNREACHABLE',
      `PSP request failed: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
  const text = await response.text();
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    throw new PaymentAdapterError('PSP_UNREACHABLE', `PSP returned non-JSON (HTTP ${response.status})`);
  }
};

export function str(value: unknown): string {
  if (value === undefined || value === null) {
    return '';
  }
  return String(value);
}

/** yymmdd in GMT+7 (ZaloPay app_trans_id prefix). */
export function yymmddVn(date: Date): string {
  const d = new Date(date.getTime() + 7 * 3600 * 1000);
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${pad(d.getUTCFullYear() % 100)}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}`;
}

export function safeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) {
    return false;
  }
  let mismatch = 0;
  for (let i = 0; i < left.length; i += 1) {
    mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return mismatch === 0;
}
