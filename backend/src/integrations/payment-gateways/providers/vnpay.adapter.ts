import { createHmac } from 'node:crypto';
import { buildVnpayRedirectUrl, formatVnpDate, verifyVnpaySecureHash } from '../vnpay-payment.port.js';
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

export type VnpayConfig = {
  tmnCode?: string;
  hashSecret?: string;
  /** Pay URL, sandbox https://sandbox.vnpayment.vn/paymentv2/vpcpay.html */
  url?: string;
  /** Merchant API (refund), sandbox https://sandbox.vnpayment.vn/merchant_webapi/api/transaction */
  apiUrl?: string;
};

/** VNPay refund checksum input (pipe-joined, HMAC-SHA512). */
export function vnpayRefundHashInput(f: Record<string, string>): string {
  return [
    f.vnp_RequestId,
    f.vnp_Version,
    f.vnp_Command,
    f.vnp_TmnCode,
    f.vnp_TransactionType,
    f.vnp_TxnRef,
    f.vnp_Amount,
    f.vnp_TransactionNo,
    f.vnp_TransactionDate,
    f.vnp_CreateBy,
    f.vnp_CreateDate,
    f.vnp_IpAddr,
    f.vnp_OrderInfo,
  ].join('|');
}

export class VnpayAdapter implements PaymentAdapter {
  readonly provider = 'vnpay' as const;
  readonly kind = 'REAL' as const;

  constructor(
    private readonly config: VnpayConfig,
    private readonly http: HttpPost = fetchHttpPost,
  ) {}

  requiredEnv() {
    return ['VNPAY_TMN_CODE', 'VNPAY_HASH_SECRET', 'VNPAY_URL', 'VNPAY_API_URL'] as const;
  }

  isConfigured(): boolean {
    const c = this.config;
    return Boolean(c.tmnCode && c.hashSecret && c.url);
  }

  private creds() {
    if (!this.isConfigured()) {
      throw new PaymentAdapterError('ADAPTER_NOT_CONFIGURED', 'VNPay is not configured');
    }
    return this.config as Required<Omit<VnpayConfig, 'apiUrl'>> & { apiUrl?: string };
  }

  async create(request: AdapterCreateRequest): Promise<AdapterCreateResult> {
    const c = this.creds();
    const params: Record<string, string> = {
      vnp_Version: '2.1.0',
      vnp_Command: 'pay',
      vnp_TmnCode: c.tmnCode,
      vnp_Amount: String(request.amountVnd * 100),
      vnp_CurrCode: 'VND',
      vnp_TxnRef: request.orderRef,
      vnp_OrderInfo: request.orderInfo,
      vnp_OrderType: 'other',
      vnp_Locale: 'vn',
      vnp_ReturnUrl: request.returnUrl,
      vnp_IpAddr: request.clientIp,
      vnp_CreateDate: formatVnpDate(request.now),
      vnp_ExpireDate: formatVnpDate(new Date(request.now.getTime() + 15 * 60 * 1000)),
    };
    if (request.methodCode === 'VNPAY_ATM') {
      // Thẻ ATM nội địa / Napas.
      params.vnp_BankCode = 'VNBANK';
    }
    return {
      providerRef: request.orderRef,
      paymentUrl: buildVnpayRedirectUrl(c.url, params, c.hashSecret),
      deeplink: null,
    };
  }

  verifyCallback(payload: Record<string, unknown>): AdapterCallback {
    const params: Record<string, string> = {};
    for (const [k, v] of Object.entries(payload)) {
      if (k.startsWith('vnp_')) {
        params[k] = str(v);
      }
    }
    const valid = this.isConfigured() && verifyVnpaySecureHash(params, this.creds().hashSecret);
    const txnRef = params.vnp_TxnRef || null;
    const response = params.vnp_ResponseCode ?? '';
    const status = params.vnp_TransactionStatus ?? '';
    const success = response === '00' && (status === '' || status === '00');
    return {
      valid,
      providerRef: txnRef,
      providerEventId: txnRef ? `${txnRef}:${params.vnp_TransactionNo ?? ''}:${response}` : null,
      success,
      amountVnd: params.vnp_Amount ? Math.round(Number(params.vnp_Amount) / 100) : null,
      providerTransId: params.vnp_TransactionNo || null,
      providerPayDate: params.vnp_PayDate || null,
      failureReason: success ? null : `VNPAY_${response}/${status}`,
    };
  }

  ack(kind: CallbackAckKind): CallbackAck {
    const map: Record<CallbackAckKind, [string, string]> = {
      OK: ['00', 'Confirm Success'],
      ALREADY: ['02', 'Order already confirmed'],
      NOT_FOUND: ['01', 'Order not found'],
      AMOUNT_MISMATCH: ['04', 'Invalid amount'],
      INVALID_SIGNATURE: ['97', 'Invalid signature'],
      ERROR: ['99', 'Unknown error'],
    };
    const [RspCode, Message] = map[kind];
    return { httpStatus: 200, body: { RspCode, Message } };
  }

  async refund(request: AdapterRefundRequest): Promise<AdapterRefundResult> {
    const c = this.creds();
    if (!c.apiUrl) {
      throw new PaymentAdapterError('ADAPTER_NOT_CONFIGURED', 'VNPAY_API_URL is not configured');
    }
    if (!request.providerPayDate) {
      throw new PaymentAdapterError('PSP_REJECTED', 'VNPay refund needs vnp_PayDate');
    }
    const fields: Record<string, string> = {
      vnp_RequestId: request.requestId.slice(0, 32),
      vnp_Version: '2.1.0',
      vnp_Command: 'refund',
      vnp_TmnCode: c.tmnCode,
      vnp_TransactionType: request.amountVnd >= request.capturedAmountVnd ? '02' : '03',
      vnp_TxnRef: request.providerRef,
      vnp_Amount: String(request.amountVnd * 100),
      vnp_TransactionNo: request.providerTransId ?? '',
      vnp_TransactionDate: request.providerPayDate,
      vnp_CreateBy: request.actorRef.slice(0, 250),
      vnp_CreateDate: formatVnpDate(request.now),
      vnp_IpAddr: request.clientIp,
      vnp_OrderInfo: request.reason,
    };
    const vnp_SecureHash = createHmac('sha512', c.hashSecret)
      .update(vnpayRefundHashInput(fields))
      .digest('hex');
    const res = await this.http(c.apiUrl, { ...fields, vnp_SecureHash }, { timeoutMs: 30_000 });
    const code = str(res.vnp_ResponseCode);
    return {
      status: code === '00' ? 'ACCEPTED' : code === '94' ? 'PENDING' : 'REJECTED',
      providerRefundRef: str(res.vnp_TransactionNo) || null,
      message: str(res.vnp_Message) || null,
    };
  }
}
