import { createHmac } from 'node:crypto';
import { verifyMomoSignature } from '../momo-payment.port.js';
import {
  PaymentAdapterError,
  fetchHttpPost,
  str,
  type AdapterCallback,
  type AdapterCreateRequest,
  type AdapterCreateResult,
  type AdapterRefundRequest,
  type AdapterRefundResult,
  type CallbackAck,
  type CallbackAckKind,
  type HttpPost,
  type PaymentAdapter,
} from './payment-adapter.js';

export type MomoConfig = {
  partnerCode?: string;
  accessKey?: string;
  secretKey?: string;
  /** e.g. https://test-payment.momo.vn (sandbox) */
  endpoint?: string;
};

const sign = (secret: string, raw: string) => createHmac('sha256', secret).update(raw).digest('hex');

/** MoMo AIO v2 (captureWallet). Docs: developers.momo.vn/v3/docs/payment/api/wallet/onetime */
export function momoCreateRawSignature(fields: {
  accessKey: string;
  amount: string;
  extraData: string;
  ipnUrl: string;
  orderId: string;
  orderInfo: string;
  partnerCode: string;
  redirectUrl: string;
  requestId: string;
  requestType: string;
}): string {
  return (
    `accessKey=${fields.accessKey}&amount=${fields.amount}&extraData=${fields.extraData}` +
    `&ipnUrl=${fields.ipnUrl}&orderId=${fields.orderId}&orderInfo=${fields.orderInfo}` +
    `&partnerCode=${fields.partnerCode}&redirectUrl=${fields.redirectUrl}` +
    `&requestId=${fields.requestId}&requestType=${fields.requestType}`
  );
}

export function momoRefundRawSignature(fields: {
  accessKey: string;
  amount: string;
  description: string;
  orderId: string;
  partnerCode: string;
  requestId: string;
  transId: string;
}): string {
  return (
    `accessKey=${fields.accessKey}&amount=${fields.amount}&description=${fields.description}` +
    `&orderId=${fields.orderId}&partnerCode=${fields.partnerCode}` +
    `&requestId=${fields.requestId}&transId=${fields.transId}`
  );
}

export class MomoAdapter implements PaymentAdapter {
  readonly provider = 'momo' as const;
  readonly kind = 'REAL' as const;

  constructor(
    private readonly config: MomoConfig,
    private readonly http: HttpPost = fetchHttpPost,
  ) {}

  requiredEnv() {
    return ['MOMO_PARTNER_CODE', 'MOMO_ACCESS_KEY', 'MOMO_SECRET_KEY', 'MOMO_ENDPOINT'] as const;
  }

  isConfigured(): boolean {
    const c = this.config;
    return Boolean(c.partnerCode && c.accessKey && c.secretKey && c.endpoint);
  }

  private creds() {
    if (!this.isConfigured()) {
      throw new PaymentAdapterError('ADAPTER_NOT_CONFIGURED', 'MoMo is not configured');
    }
    return this.config as Required<MomoConfig>;
  }

  async create(request: AdapterCreateRequest): Promise<AdapterCreateResult> {
    const c = this.creds();
    const fields = {
      accessKey: c.accessKey,
      amount: String(request.amountVnd),
      extraData: '',
      ipnUrl: request.ipnUrl,
      orderId: request.orderRef,
      orderInfo: request.orderInfo,
      partnerCode: c.partnerCode,
      redirectUrl: request.returnUrl,
      requestId: request.orderRef,
      requestType: 'captureWallet',
    };
    const signature = sign(c.secretKey, momoCreateRawSignature(fields));
    const res = await this.http(
      `${c.endpoint.replace(/\/$/, '')}/v2/gateway/api/create`,
      {
        partnerCode: c.partnerCode,
        requestId: fields.requestId,
        amount: request.amountVnd,
        orderId: fields.orderId,
        orderInfo: fields.orderInfo,
        redirectUrl: fields.redirectUrl,
        ipnUrl: fields.ipnUrl,
        requestType: fields.requestType,
        extraData: '',
        lang: 'vi',
        signature,
      },
      { timeoutMs: 30_000 },
    );
    if (Number(res.resultCode) !== 0 || typeof res.payUrl !== 'string') {
      throw new PaymentAdapterError(
        'PSP_REJECTED',
        `MoMo create failed (${str(res.resultCode)}): ${str(res.message)}`,
      );
    }
    return {
      providerRef: request.orderRef,
      paymentUrl: res.payUrl,
      deeplink: typeof res.deeplink === 'string' ? res.deeplink : null,
    };
  }

  verifyCallback(payload: Record<string, unknown>): AdapterCallback {
    const valid = this.isConfigured() && verifyMomoSignature(payload, this.creds());
    const resultCode = str(payload.resultCode);
    const orderId = str(payload.orderId) || null;
    return {
      valid,
      providerRef: orderId,
      providerEventId: orderId ? `${orderId}:${str(payload.transId)}:${resultCode}` : null,
      success: resultCode === '0',
      amountVnd: payload.amount === undefined ? null : Number(payload.amount),
      providerTransId: str(payload.transId) || null,
      providerPayDate: str(payload.responseTime) || null,
      failureReason: resultCode === '0' ? null : `MOMO_${resultCode}: ${str(payload.message)}`,
    };
  }

  /** MoMo only needs HTTP 204 for a received IPN. */
  ack(kind: CallbackAckKind): CallbackAck {
    if (kind === 'INVALID_SIGNATURE') {
      return { httpStatus: 400, body: { message: 'invalid signature' } };
    }
    return { httpStatus: 204, body: undefined };
  }

  async refund(request: AdapterRefundRequest): Promise<AdapterRefundResult> {
    const c = this.creds();
    if (!request.providerTransId) {
      throw new PaymentAdapterError('PSP_REJECTED', 'MoMo refund needs transId');
    }
    const fields = {
      accessKey: c.accessKey,
      amount: String(request.amountVnd),
      description: request.reason,
      orderId: request.requestId,
      partnerCode: c.partnerCode,
      requestId: request.requestId,
      transId: request.providerTransId,
    };
    const signature = sign(c.secretKey, momoRefundRawSignature(fields));
    const res = await this.http(
      `${c.endpoint.replace(/\/$/, '')}/v2/gateway/api/refund`,
      {
        partnerCode: c.partnerCode,
        orderId: fields.orderId,
        requestId: fields.requestId,
        amount: request.amountVnd,
        transId: Number(request.providerTransId),
        lang: 'vi',
        description: request.reason,
        signature,
      },
      { timeoutMs: 30_000 },
    );
    const code = Number(res.resultCode);
    return {
      status: code === 0 ? 'ACCEPTED' : code === 1000 || code === 7000 ? 'PENDING' : 'REJECTED',
      providerRefundRef: str(res.transId) || null,
      message: str(res.message) || null,
    };
  }
}
