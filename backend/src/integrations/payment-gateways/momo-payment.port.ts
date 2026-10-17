import { createHmac, randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { PAYMENT_REPOSITORY } from '../../modules/payment/payment.constants.js';
import type {
  CreateRedirectIntentInput,
  CreateSandboxIntentInput,
  PaymentIntentView,
  PaymentPort,
  RedirectPaymentIntentView,
} from '../../modules/payment/payment-port.js';
import { UnavailablePaymentError } from '../../modules/payment/payment-port.js';
import type { PaymentRepository } from '../../modules/payment/payment.repository.js';

export type MomoCredentials = {
  partnerCode: string;
  accessKey: string;
  secretKey: string;
  endpoint: string;
};

/**
 * Creates a MoMo redirect intent (URL-only). Does not call MoMo create API over the network
 * in this phase — builds a signed query URL for checkout. Capture requires verified IPN.
 */
@Injectable()
export class MomoPaymentPort implements PaymentPort {
  constructor(
    private readonly credentials: MomoCredentials,
    @Inject(PAYMENT_REPOSITORY) private readonly payments: PaymentRepository,
  ) {}

  async createSandboxIntent(_input: CreateSandboxIntentInput): Promise<PaymentIntentView> {
    throw new UnavailablePaymentError('MoMo port does not create sandbox COD intents');
  }

  async markCodCollected(): Promise<PaymentIntentView> {
    throw new UnavailablePaymentError('MoMo port does not mark COD collected');
  }

  async createRedirectIntent(input: CreateRedirectIntentInput): Promise<RedirectPaymentIntentView> {
    if (!Number.isInteger(input.amountVnd) || input.amountVnd <= 0) {
      throw new UnavailablePaymentError('MoMo amount must be a positive integer VND');
    }
    const providerRef = `momo_${randomUUID().replace(/-/g, '').slice(0, 24)}`;
    const orderInfo = input.orderInfo ?? `DealGo ${input.entityType}`;
    const requestId = providerRef;
    const extraData = '';
    const rawSignature = [
      `accessKey=${this.credentials.accessKey}`,
      `amount=${input.amountVnd}`,
      `extraData=${extraData}`,
      `orderId=${providerRef}`,
      `orderInfo=${orderInfo}`,
      `partnerCode=${this.credentials.partnerCode}`,
      `redirectUrl=${input.returnUrl}`,
      `requestId=${requestId}`,
      `requestType=captureWallet`,
    ].join('&');
    const signature = createHmac('sha256', this.credentials.secretKey)
      .update(rawSignature)
      .digest('hex');
    const paymentUrl = buildMomoRedirectUrl(this.credentials.endpoint, {
      partnerCode: this.credentials.partnerCode,
      accessKey: this.credentials.accessKey,
      requestId,
      amount: String(input.amountVnd),
      orderId: providerRef,
      orderInfo,
      redirectUrl: input.returnUrl,
      ipnUrl: input.returnUrl,
      extraData,
      requestType: 'captureWallet',
      signature,
      lang: 'vi',
    });
    return this.payments.createRedirectIntent({
      ...input,
      method: 'MOMO',
      provider: 'momo',
      providerRef,
      paymentUrl,
      status: 'PENDING_REDIRECT',
    });
  }
}

export function buildMomoRedirectUrl(
  endpoint: string,
  params: Record<string, string>,
): string {
  const query = Object.entries(params)
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
    .join('&');
  const base = endpoint.includes('?') ? endpoint : `${endpoint.replace(/\/$/, '')}/pay`;
  return `${base}?${query}`;
}

function coerceFieldString(value: unknown): string {
  if (value === null || value === undefined) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'bigint' || typeof value === 'boolean') {
    return String(value);
  }
  return '';
}

export function verifyMomoSignature(
  payload: Record<string, unknown>,
  credentials: Pick<MomoCredentials, 'accessKey' | 'secretKey'>,
): boolean {
  const signature = typeof payload.signature === 'string' ? payload.signature : '';
  if (!signature) {
    return false;
  }
  const amount = coerceFieldString(payload.amount);
  const extraData = coerceFieldString(payload.extraData);
  const message = coerceFieldString(payload.message);
  const orderId = coerceFieldString(payload.orderId);
  const orderInfo = coerceFieldString(payload.orderInfo);
  const orderType = coerceFieldString(payload.orderType);
  const partnerCode = coerceFieldString(payload.partnerCode);
  const payType = coerceFieldString(payload.payType);
  const requestId = coerceFieldString(payload.requestId);
  const responseTime = coerceFieldString(payload.responseTime);
  const resultCode = coerceFieldString(payload.resultCode);
  const transId = coerceFieldString(payload.transId);
  const raw = [
    `accessKey=${credentials.accessKey}`,
    `amount=${amount}`,
    `extraData=${extraData}`,
    `message=${message}`,
    `orderId=${orderId}`,
    `orderInfo=${orderInfo}`,
    `orderType=${orderType}`,
    `partnerCode=${partnerCode}`,
    `payType=${payType}`,
    `requestId=${requestId}`,
    `responseTime=${responseTime}`,
    `resultCode=${resultCode}`,
    `transId=${transId}`,
  ].join('&');
  const expected = createHmac('sha256', credentials.secretKey).update(raw).digest('hex');
  return timingSafeEqualHex(expected, signature);
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
