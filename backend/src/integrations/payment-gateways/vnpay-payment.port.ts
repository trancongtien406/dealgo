import { createHmac, randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { PAYMENT_REPOSITORY, type PaymentEntityTypeName } from '../../modules/payment/payment.constants.js';
import type {
  CreateRedirectIntentInput,
  CreateSandboxIntentInput,
  PaymentIntentView,
  PaymentPort,
  RedirectPaymentIntentView,
} from '../../modules/payment/payment-port.js';
import { UnavailablePaymentError } from '../../modules/payment/payment-port.js';
import type { PaymentRepository } from '../../modules/payment/payment.repository.js';

export type VnpayCredentials = {
  tmnCode: string;
  hashSecret: string;
  url: string;
};

/**
 * Creates a VNPAY redirect intent only. Capture requires verified IPN/webhook —
 * this port never marks money as collected on create.
 */
@Injectable()
export class VnpayPaymentPort implements PaymentPort {
  constructor(
    private readonly credentials: VnpayCredentials,
    @Inject(PAYMENT_REPOSITORY) private readonly payments: PaymentRepository,
  ) {}

  async createSandboxIntent(_input: CreateSandboxIntentInput): Promise<PaymentIntentView> {
    throw new UnavailablePaymentError('VNPAY port does not create sandbox COD intents');
  }

  async markCodCollected(): Promise<PaymentIntentView> {
    throw new UnavailablePaymentError('VNPAY port does not mark COD collected');
  }

  async createRedirectIntent(input: CreateRedirectIntentInput): Promise<RedirectPaymentIntentView> {
    if (!Number.isInteger(input.amountVnd) || input.amountVnd <= 0) {
      throw new UnavailablePaymentError('VNPAY amount must be a positive integer VND');
    }
    const providerRef = `vnp_${randomUUID().replace(/-/g, '').slice(0, 24)}`;
    const createDate = formatVnpDate(new Date());
    const params: Record<string, string> = {
      vnp_Version: '2.1.0',
      vnp_Command: 'pay',
      vnp_TmnCode: this.credentials.tmnCode,
      vnp_Amount: String(input.amountVnd * 100),
      vnp_CurrCode: 'VND',
      vnp_TxnRef: providerRef,
      vnp_OrderInfo: input.orderInfo ?? `DealGo ${input.entityType} ${input.entityId}`,
      vnp_OrderType: 'other',
      vnp_Locale: 'vn',
      vnp_ReturnUrl: input.returnUrl,
      vnp_CreateDate: createDate,
      vnp_IpAddr: '127.0.0.1',
    };
    const paymentUrl = buildVnpayRedirectUrl(this.credentials.url, params, this.credentials.hashSecret);
    return this.payments.createRedirectIntent({
      ...input,
      method: 'VNPAY',
      provider: 'vnpay',
      providerRef,
      paymentUrl,
      status: 'PENDING_REDIRECT',
    });
  }
}

export function buildVnpayRedirectUrl(
  baseUrl: string,
  params: Record<string, string>,
  hashSecret: string,
): string {
  const sorted = Object.keys(params)
    .filter((key) => params[key] !== undefined && params[key] !== '')
    .sort();
  const query = sorted
    .map((key) => `${key}=${encodeURIComponent(params[key]!).replace(/%20/g, '+')}`)
    .join('&');
  const secureHash = createHmac('sha512', hashSecret).update(query).digest('hex');
  return `${baseUrl}?${query}&vnp_SecureHash=${secureHash}`;
}

export function verifyVnpaySecureHash(
  params: Record<string, string>,
  hashSecret: string,
): boolean {
  const secureHash = params.vnp_SecureHash ?? params.vnp_SecureHashType;
  if (!secureHash) {
    return false;
  }
  const copy = { ...params };
  delete copy.vnp_SecureHash;
  delete copy.vnp_SecureHashType;
  const sorted = Object.keys(copy)
    .filter((key) => copy[key] !== undefined && copy[key] !== '')
    .sort();
  const query = sorted
    .map((key) => `${key}=${encodeURIComponent(copy[key]!).replace(/%20/g, '+')}`)
    .join('&');
  const expected = createHmac('sha512', hashSecret).update(query).digest('hex');
  return timingSafeEqualHex(expected, secureHash);
}

/** VNPay expects yyyyMMddHHmmss in GMT+7 (Asia/Ho_Chi_Minh), not UTC. */
export function formatVnpDate(date: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  date = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  return (
    `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}` +
    `${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`
  );
}

function timingSafeEqualHex(left: string, right: string): boolean {
  if (left.length !== right.length) {
    return false;
  }
  let mismatch = 0;
  for (let i = 0; i < left.length; i += 1) {
    mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return mismatch === 0;
}

export type { PaymentEntityTypeName };
