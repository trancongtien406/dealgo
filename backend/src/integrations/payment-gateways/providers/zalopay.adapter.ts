import { createHmac, randomUUID } from 'node:crypto';
import {
  PaymentAdapterError,
  fetchHttpPost,
  safeEqual,
  str,
  yymmddVn,
  type AdapterCallback,
  type AdapterCreateRequest,
  type AdapterCreateResult,
  type AdapterRefundRequest,
  type AdapterQueryRequest,
  type AdapterQueryResult,
  type AdapterRefundResult,
  type CallbackAck,
  type CallbackAckKind,
  type HttpPost,
  type PaymentAdapter,
} from './payment-adapter.js';

export type ZalopayConfig = {
  appId?: string;
  key1?: string;
  key2?: string;
  /** e.g. https://sb-openapi.zalopay.vn (sandbox) */
  endpoint?: string;
};

const hmac = (key: string, raw: string) => createHmac('sha256', key).update(raw).digest('hex');

/** ZaloPay v2 create MAC: app_id|app_trans_id|app_user|amount|app_time|embed_data|item (key1). */
export function zalopayCreateMacInput(f: {
  app_id: string;
  app_trans_id: string;
  app_user: string;
  amount: string;
  app_time: string;
  embed_data: string;
  item: string;
}): string {
  return [f.app_id, f.app_trans_id, f.app_user, f.amount, f.app_time, f.embed_data, f.item].join('|');
}

export class ZalopayAdapter implements PaymentAdapter {
  readonly provider = 'zalopay' as const;
  readonly kind = 'REAL' as const;

  constructor(
    private readonly config: ZalopayConfig,
    private readonly http: HttpPost = fetchHttpPost,
  ) {}

  requiredEnv() {
    return ['ZALOPAY_APP_ID', 'ZALOPAY_KEY1', 'ZALOPAY_KEY2', 'ZALOPAY_ENDPOINT'] as const;
  }

  isConfigured(): boolean {
    const c = this.config;
    return Boolean(c.appId && c.key1 && c.key2 && c.endpoint);
  }

  private creds() {
    if (!this.isConfigured()) {
      throw new PaymentAdapterError('ADAPTER_NOT_CONFIGURED', 'ZaloPay is not configured');
    }
    return this.config as Required<ZalopayConfig>;
  }

  async create(request: AdapterCreateRequest): Promise<AdapterCreateResult> {
    const c = this.creds();
    // app_trans_id must start with yymmdd (GMT+7) and be unique per app.
    const appTransId = `${yymmddVn(request.now)}_${request.orderRef}`.slice(0, 40);
    const fields = {
      app_id: c.appId,
      app_trans_id: appTransId,
      app_user: request.userRef.slice(0, 50),
      amount: String(request.amountVnd),
      app_time: String(request.now.getTime()),
      embed_data: JSON.stringify({ redirecturl: request.returnUrl }),
      item: '[]',
    };
    const mac = hmac(c.key1, zalopayCreateMacInput(fields));
    const res = await this.http(
      `${c.endpoint.replace(/\/$/, '')}/v2/create`,
      {
        ...fields,
        description: request.orderInfo,
        bank_code: '',
        callback_url: request.ipnUrl,
        mac,
      },
      { form: true, timeoutMs: 30_000 },
    );
    if (Number(res.return_code) !== 1 || typeof res.order_url !== 'string') {
      throw new PaymentAdapterError(
        'PSP_REJECTED',
        `ZaloPay create failed (${str(res.return_code)}/${str(res.sub_return_code)}): ${str(res.return_message)}`,
      );
    }
    return { providerRef: appTransId, paymentUrl: res.order_url, deeplink: null };
  }

  /** Callback body: { data: "<json>", mac: HMAC-SHA256(key2, data), type }. Sent only on success. */
  verifyCallback(payload: Record<string, unknown>): AdapterCallback {
    const data = str(payload.data);
    const mac = str(payload.mac);
    const valid =
      this.isConfigured() && data.length > 0 && safeEqual(hmac(this.creds().key2, data), mac);
    let parsed: Record<string, unknown> = {};
    try {
      parsed = data ? (JSON.parse(data) as Record<string, unknown>) : {};
    } catch {
      parsed = {};
    }
    const appTransId = str(parsed.app_trans_id) || null;
    return {
      valid,
      providerRef: appTransId,
      providerEventId: appTransId ? `${appTransId}:${str(parsed.zp_trans_id)}` : null,
      success: true,
      amountVnd: parsed.amount === undefined ? null : Number(parsed.amount),
      providerTransId: str(parsed.zp_trans_id) || null,
      providerPayDate: str(parsed.server_time) || null,
      failureReason: null,
    };
  }

  ack(kind: CallbackAckKind): CallbackAck {
    if (kind === 'INVALID_SIGNATURE') {
      return { httpStatus: 200, body: { return_code: -1, return_message: 'mac not equal' } };
    }
    if (kind === 'ERROR') {
      // return_code 0 asks ZaloPay to retry the callback.
      return { httpStatus: 200, body: { return_code: 0, return_message: 'retry' } };
    }
    return { httpStatus: 200, body: { return_code: 1, return_message: 'success' } };
  }

  async refund(request: AdapterRefundRequest): Promise<AdapterRefundResult> {
    const c = this.creds();
    if (!request.providerTransId) {
      throw new PaymentAdapterError('PSP_REJECTED', 'ZaloPay refund needs zp_trans_id');
    }
    const timestamp = String(request.now.getTime());
    const mRefundId = `${yymmddVn(request.now)}_${c.appId}_${randomUUID().replace(/-/g, '').slice(0, 12)}`;
    const mac = hmac(
      c.key1,
      [c.appId, request.providerTransId, String(request.amountVnd), request.reason, timestamp].join('|'),
    );
    const res = await this.http(
      `${c.endpoint.replace(/\/$/, '')}/v2/refund`,
      {
        app_id: c.appId,
        m_refund_id: mRefundId,
        zp_trans_id: request.providerTransId,
        amount: request.amountVnd,
        timestamp,
        description: request.reason,
        mac,
      },
      { form: true, timeoutMs: 30_000 },
    );
    const code = Number(res.return_code);
    return {
      status: code === 1 ? 'ACCEPTED' : code === 3 ? 'PENDING' : 'REJECTED',
      providerRefundRef: str(res.refund_id) || mRefundId,
      message: str(res.return_message) || null,
    };
  }

  /** POST /v2/query, mac = HMAC(key1, app_id|app_trans_id|key1). return_code 1 paid, 2 failed, 3 pending. */
  async query(request: AdapterQueryRequest): Promise<AdapterQueryResult> {
    const c = this.creds();
    const res = await this.http(
      `${c.endpoint.replace(/\/$/, '')}/v2/query`,
      {
        app_id: c.appId,
        app_trans_id: request.providerRef,
        mac: hmac(c.key1, `${c.appId}|${request.providerRef}|${c.key1}`),
      },
      { form: true, timeoutMs: 30_000 },
    );
    const code = Number(res.return_code);
    const processing = res.is_processing === true || str(res.is_processing) === 'true';
    const state = code === 1 ? 'CAPTURED' : code === 3 || processing ? 'PENDING' : code === 2 ? 'FAILED' : 'UNKNOWN';
    return {
      state,
      amountVnd: res.amount === undefined ? null : Number(res.amount),
      providerTransId: str(res.zp_trans_id) || null,
      providerPayDate: str(res.server_time) || null,
      message: `ZALOPAY_${str(res.return_code)}: ${str(res.return_message)}`.slice(0, 255),
    };
  }
}
