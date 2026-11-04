import { createHmac } from 'node:crypto';
import {
  PaymentAdapterError,
  safeEqual,
  str,
  type AdapterCallback,
  type AdapterCreateRequest,
  type AdapterCreateResult,
  type AdapterQueryRequest,
  type AdapterQueryResult,
  type AdapterRefundRequest,
  type AdapterRefundResult,
  type CallbackAck,
  type CallbackAckKind,
  type PaymentAdapter,
} from './payment-adapter.js';

export type PayosConfig = {
  clientId?: string;
  apiKey?: string;
  checksumKey?: string;
  /** https://api-merchant.payos.vn (sandbox uses the same host, per payOS docs). */
  endpoint?: string;
};

export type PayosHttpRequest = (
  method: 'GET' | 'POST',
  url: string,
  headers: Record<string, string>,
  body: Record<string, unknown> | null,
  options: { timeoutMs: number },
) => Promise<Record<string, unknown>>;

export const fetchPayosRequest: PayosHttpRequest = async (
  method,
  url,
  headers,
  body,
  options,
) => {
  let response: Response;
  try {
    response = await fetch(url, {
      method,
      headers: { ...headers, 'Content-Type': 'application/json; charset=UTF-8' },
      ...(method === 'POST' && body ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(options.timeoutMs),
    });
  } catch (error) {
    throw new PaymentAdapterError(
      'PSP_UNREACHABLE',
      `payOS request failed: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
  const text = await response.text();
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    throw new PaymentAdapterError('PSP_UNREACHABLE', `payOS returned non-JSON (HTTP ${response.status})`);
  }
};

function signatureValue(value: unknown): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'bigint') {
    return String(value);
  }
  return JSON.stringify(value);
}

/**
 * payOS signature: HMAC-SHA256 over `key=value&...` sorted by key (alphabetical).
 * Used both for create-payment-link payloads and for `data` of webhook callbacks.
 */
export function payosSignature(data: Record<string, unknown>, checksumKey: string): string {
  const query = Object.keys(data)
    .filter((key) => data[key] !== undefined && data[key] !== null)
    .sort()
    .map((key) => `${key}=${signatureValue(data[key])}`)
    .join('&');
  return createHmac('sha256', checksumKey).update(query).digest('hex');
}

/**
 * payOS payment links only, no payouts. A2A: money moves straight to the merchant bank
 * account, so this adapter never holds funds and never claims a capture without a signed
 * webhook.
 */
export class PayosAdapter implements PaymentAdapter {
  readonly provider = 'payos' as const;
  readonly kind = 'REAL' as const;

  constructor(
    private readonly config: PayosConfig,
    private readonly http: PayosHttpRequest = fetchPayosRequest,
  ) {}

  requiredEnv() {
    return ['PAYOS_CLIENT_ID', 'PAYOS_API_KEY', 'PAYOS_CHECKSUM_KEY', 'PAYOS_ENDPOINT'] as const;
  }

  isConfigured(): boolean {
    return Boolean(this.config.clientId && this.config.apiKey && this.config.checksumKey);
  }

  private creds() {
    if (!this.isConfigured()) {
      throw new PaymentAdapterError('ADAPTER_NOT_CONFIGURED', 'payOS is not configured');
    }
    return {
      clientId: this.config.clientId!,
      apiKey: this.config.apiKey!,
      checksumKey: this.config.checksumKey!,
      endpoint: (this.config.endpoint ?? 'https://api-merchant.payos.vn').replace(/\/+$/, ''),
    };
  }

  private headers(clientId: string, apiKey: string): Record<string, string> {
    return { 'x-client-id': clientId, 'x-api-key': apiKey };
  }

  async create(request: AdapterCreateRequest): Promise<AdapterCreateResult> {
    const c = this.creds();
    const orderCode = Number(request.orderRef);
    if (!Number.isSafeInteger(orderCode) || orderCode <= 0) {
      throw new PaymentAdapterError(
        'PSP_REJECTED',
        'payOS orderRef must be a positive integer order code',
      );
    }
    if (!Number.isSafeInteger(request.amountVnd) || request.amountVnd <= 0) {
      throw new PaymentAdapterError('PSP_REJECTED', 'payOS amount must be a positive integer VND');
    }
    const cancelUrl = request.cancelUrl ?? request.returnUrl;
    // payOS caps the transfer description at 25 characters.
    const description = request.orderInfo.slice(0, 25);
    const signed = {
      amount: request.amountVnd,
      cancelUrl,
      description,
      orderCode,
      returnUrl: request.returnUrl,
    };
    const response = await this.http(
      'POST',
      `${c.endpoint}/v2/payment-requests`,
      this.headers(c.clientId, c.apiKey),
      { ...signed, signature: payosSignature(signed, c.checksumKey) },
      { timeoutMs: 30_000 },
    );
    if (str(response.code) !== '00') {
      throw new PaymentAdapterError(
        'PSP_REJECTED',
        `payOS rejected the payment link: ${str(response.desc) || str(response.code)}`,
      );
    }
    const data = (response.data ?? {}) as Record<string, unknown>;
    return {
      providerRef: String(orderCode),
      paymentUrl: str(data.checkoutUrl) || null,
      deeplink: null,
      qrCode: str(data.qrCode) || null,
    };
  }

  verifyCallback(payload: Record<string, unknown>): AdapterCallback {
    const data = (payload.data ?? {}) as Record<string, unknown>;
    const valid =
      this.isConfigured() &&
      safeEqual(payosSignature(data, this.creds().checksumKey), str(payload.signature));
    const rawOrderCode = Number(data.orderCode);
    const orderCode = Number.isSafeInteger(rawOrderCode) ? rawOrderCode : null;
    const amount = Number(data.amount);
    const success = payload.success === true && str(data.code) === '00';
    return {
      valid,
      providerRef: orderCode === null ? null : String(orderCode),
      providerEventId:
        orderCode === null ? null : `${orderCode}:${str(data.reference) || 'none'}`,
      success,
      amountVnd: Number.isSafeInteger(amount) ? amount : null,
      providerTransId: str(data.reference) || null,
      providerPayDate: str(data.transactionDateTime) || null,
      failureReason: success
        ? null
        : str(data.desc) || str(payload.desc) || 'PAYOS_PAYMENT_FAILED',
    };
  }

  ack(kind: CallbackAckKind): CallbackAck {
    // payOS retries non-2xx responses; acknowledge every handled case so a forged or
    // duplicate callback cannot make the provider hammer the endpoint.
    const accepted = kind === 'OK' || kind === 'ALREADY';
    return {
      httpStatus: 200,
      body: { code: accepted ? '00' : '01', desc: accepted ? 'success' : kind },
    };
  }

  async refund(request: AdapterRefundRequest): Promise<AdapterRefundResult> {
    // A2A has no card-style refund API: Ops returns unused credit to the verified source
    // bank account and records the bank reference.
    return {
      status: 'REJECTED',
      providerRefundRef: null,
      message: `payOS refunds are manual for ${request.providerRef}; use the Ops bank transfer flow`,
    };
  }

  async query(request: AdapterQueryRequest): Promise<AdapterQueryResult> {
    const c = this.creds();
    const orderCode = Number(request.providerRef);
    if (!Number.isSafeInteger(orderCode) || orderCode <= 0) {
      return { state: 'UNKNOWN', amountVnd: null, providerTransId: null, providerPayDate: null, message: 'Invalid order code' };
    }
    const response = await this.http(
      'GET',
      `${c.endpoint}/v2/payment-requests/${orderCode}`,
      this.headers(c.clientId, c.apiKey),
      null,
      { timeoutMs: 20_000 },
    );
    if (str(response.code) !== '00') {
      return {
        state: 'UNKNOWN',
        amountVnd: null,
        providerTransId: null,
        providerPayDate: null,
        message: `${str(response.desc) || str(response.code)}`.slice(0, 255),
      };
    }
    const data = (response.data ?? {}) as Record<string, unknown>;
    const status = str(data.status).toUpperCase();
    const state =
      status === 'PAID'
        ? 'CAPTURED'
        : status === 'PENDING' || status === 'PROCESSING'
          ? 'PENDING'
          : status === 'CANCELLED' || status === 'EXPIRED' || status === 'FAILED'
            ? 'FAILED'
            : 'UNKNOWN';
    const amount = Number(data.amount);
    return {
      state,
      amountVnd: Number.isSafeInteger(amount) ? amount : null,
      providerTransId: str(data.transactionReference) || str(data.reference) || null,
      providerPayDate: str(data.transactionDateTime) || null,
      message: `PAYOS_${status}`,
    };
  }
}
