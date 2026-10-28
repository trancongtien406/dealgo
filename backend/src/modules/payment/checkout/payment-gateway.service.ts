import { randomUUID } from 'node:crypto';
import { HttpException, Inject, Injectable, Logger, Optional } from '@nestjs/common';
import type { PaymentMethodCode, PaymentServiceCode } from '../../../platform/settings/payment-method-registry.js';
import {
  PaymentAdapterError,
  type CallbackAck,
  type PaymentAdapter,
} from '../../../integrations/payment-gateways/providers/index.js';
import { LedgerService } from '../../ledger/ledger.service.js';
import { CHECKOUT_REPOSITORY, type PaymentEntityTypeName, type PaymentProviderName } from '../payment.constants.js';
import type { CheckoutIntent, CheckoutRepository } from './checkout.repository.js';
import { PAYMENT_ADAPTERS, type PaymentAdapterMap } from './payment-adapters.js';
import { PAYMENT_GATEWAY_OPTIONS, type PaymentGatewayOptions } from './payment-gateway.options.js';
import { catalogEntry } from './payment-method.catalog.js';
import { PaymentMethodRegistryService } from './payment-method-registry.service.js';

/** Customer-facing status of a job's payment. */
export type CheckoutStatus =
  | 'CASH'
  | 'NOT_STARTED'
  | 'PENDING'
  | 'PAID'
  | 'FAILED'
  | 'EXPIRED'
  | 'REFUND_PENDING'
  | 'REFUNDED';

export type CheckoutView = {
  entityType: PaymentEntityTypeName;
  entityId: string;
  methodCode: PaymentMethodCode;
  status: CheckoutStatus;
  amountVnd: number | null;
  paymentUrl: string | null;
  deeplink: string | null;
  intentId: string | null;
  failureReason: string | null;
};

const PENDING_TTL_MS = 15 * 60 * 1000;

function paymentError(status: number, errorCode: string, message: string) {
  return new HttpException({ message, errorCode }, status);
}

export function toCheckoutStatus(intent: CheckoutIntent | null, now = new Date()): CheckoutStatus {
  if (!intent) {
    return 'NOT_STARTED';
  }
  switch (intent.status) {
    case 'CAPTURED':
      return 'PAID';
    case 'FAILED':
      return 'FAILED';
    case 'EXPIRED':
      return 'EXPIRED';
    case 'REFUND_PENDING':
      return 'REFUND_PENDING';
    case 'REFUNDED':
      return 'REFUNDED';
    case 'PENDING_REDIRECT':
    case 'CREATED':
      return now.getTime() - intent.updatedAt.getTime() > PENDING_TTL_MS ? 'EXPIRED' : 'PENDING';
    default:
      return 'NOT_STARTED';
  }
}

@Injectable()
export class PaymentGatewayService {
  private readonly logger = new Logger(PaymentGatewayService.name);

  constructor(
    @Inject(CHECKOUT_REPOSITORY) private readonly repo: CheckoutRepository,
    @Inject(PAYMENT_ADAPTERS) private readonly adapters: PaymentAdapterMap,
    @Inject(PAYMENT_GATEWAY_OPTIONS) private readonly options: PaymentGatewayOptions,
    private readonly registry: PaymentMethodRegistryService,
    @Optional() private readonly ledger?: LedgerService,
  ) {}

  /** Records the customer's chosen method (already validated by the caller's service). */
  async recordSelection(entityType: PaymentEntityTypeName, entityId: string, code: PaymentMethodCode) {
    await this.repo.setSelection(entityType, entityId, code);
  }

  async getSelection(entityType: PaymentEntityTypeName, entityId: string): Promise<PaymentMethodCode> {
    return (await this.repo.getSelection(entityType, entityId)) ?? 'CASH';
  }

  async status(entityType: PaymentEntityTypeName, entityId: string, now = new Date()): Promise<CheckoutView> {
    const methodCode = await this.getSelection(entityType, entityId);
    if (methodCode === 'CASH') {
      return this.cashView(entityType, entityId);
    }
    const entry = catalogEntry(methodCode);
    const intent = await this.repo.findByEntityMethod(entityType, entityId, entry.intentMethod);
    return this.toView(entityType, entityId, methodCode, intent, now);
  }

  /**
   * Starts (or resumes) an online payment. Amount always comes from the server-side job.
   * CASH just records the choice.
   */
  async start(input: {
    entityType: PaymentEntityTypeName;
    entityId: string;
    service: PaymentServiceCode;
    methodCode: string;
    amountVnd: number;
    userId: string;
    clientIp?: string;
    now?: Date;
  }): Promise<CheckoutView> {
    const now = input.now ?? new Date();
    const code = await this.registry.assertSelectable(input.service, input.methodCode);
    const entry = catalogEntry(code);

    // Never switch away from (or double-charge) a job that is already paid.
    const latest = await this.repo.latestForEntity(input.entityType, input.entityId);
    if (latest && ['CAPTURED', 'REFUND_PENDING', 'REFUNDED'].includes(latest.status)) {
      const paidCode = (latest.methodCode as PaymentMethodCode | null) ?? code;
      return this.toView(input.entityType, input.entityId, paidCode, latest, now);
    }

    await this.repo.setSelection(input.entityType, input.entityId, code);
    if (code === 'CASH' || entry.provider === null) {
      return this.cashView(input.entityType, input.entityId);
    }
    if (!Number.isSafeInteger(input.amountVnd) || input.amountVnd <= 0) {
      throw paymentError(409, 'PAYMENT_AMOUNT_NOT_READY', 'The amount is not final yet');
    }
    const existing = await this.repo.findByEntityMethod(input.entityType, input.entityId, entry.intentMethod);
    if (
      existing &&
      existing.methodCode === code &&
      existing.amountVnd === input.amountVnd &&
      toCheckoutStatus(existing, now) === 'PENDING'
    ) {
      return this.toView(input.entityType, input.entityId, code, existing, now);
    }

    const adapter = this.adapterFor(entry.provider);
    const base = this.options.publicBaseUrl!.replace(/\/$/, '');
    const orderRef = `DG${input.entityType === 'RIDE' ? 'R' : 'F'}${now.getTime().toString(36)}${randomUUID().replace(/-/g, '').slice(0, 10)}`.toUpperCase();
    let created;
    try {
      created = await adapter.create({
        orderRef,
        amountVnd: input.amountVnd,
        orderInfo: `DealGo ${input.entityType === 'RIDE' ? 'chuyen xe' : 'don do an'} ${orderRef}`,
        returnUrl: `${base}/v1/payments/return/${entry.provider}/${input.entityType}/${input.entityId}`,
        ipnUrl: `${base}/v1/payments/ipn/${entry.provider}`,
        clientIp: input.clientIp || '127.0.0.1',
        userRef: input.userId,
        methodCode: code,
        now,
      });
    } catch (error) {
      if (error instanceof PaymentAdapterError) {
        this.logger.warn(`payment create failed (${entry.provider}): ${error.message}`);
        throw paymentError(502, 'PAYMENT_PROVIDER_ERROR', 'Cổng thanh toán đang lỗi, vui lòng chọn tiền mặt hoặc thử lại');
      }
      throw error;
    }
    const intent = await this.repo.upsertAttempt({
      entityType: input.entityType,
      entityId: input.entityId,
      method: entry.intentMethod,
      methodCode: code,
      provider: entry.provider,
      amountVnd: input.amountVnd,
      providerRef: created.providerRef,
      paymentUrl: created.paymentUrl,
      deeplink: created.deeplink,
    });
    return this.toView(input.entityType, input.entityId, code, intent, now);
  }

  /** Signed IPN/callback. Idempotent: replays and already-final intents are acknowledged. */
  async handleCallback(provider: PaymentProviderName, payload: Record<string, unknown>): Promise<CallbackAck> {
    const adapter = this.adapters[provider];
    if (!adapter || adapter.kind !== 'REAL') {
      return { httpStatus: 404, body: { message: 'Unknown provider' } };
    }
    const cb = adapter.verifyCallback(payload);
    if (!cb.valid || !cb.providerRef || !cb.providerEventId) {
      return adapter.ack('INVALID_SIGNATURE');
    }
    const intent = await this.repo.findByProviderRef(provider, cb.providerRef);
    if (!intent) {
      return adapter.ack('NOT_FOUND');
    }
    if (cb.amountVnd !== null && cb.amountVnd !== intent.amountVnd) {
      return adapter.ack('AMOUNT_MISMATCH');
    }
    const fresh = await this.repo.recordEvent(
      provider,
      cb.providerEventId,
      intent.id,
      cb.success ? 'CAPTURED' : 'FAILED',
    );
    if (!fresh || ['CAPTURED', 'REFUND_PENDING', 'REFUNDED'].includes(intent.status)) {
      return adapter.ack(provider === 'vnpay' && !fresh ? 'ALREADY' : 'OK');
    }
    if (cb.success) {
      await this.repo.update(intent.id, {
        status: 'CAPTURED',
        providerTransId: cb.providerTransId,
        providerPayDate: cb.providerPayDate,
        failureReason: null,
      });
      await this.postLedger('PSP_PAYMENT_CAPTURED', intent, intent.amountVnd);
    } else {
      await this.repo.update(intent.id, { status: 'FAILED', failureReason: cb.failureReason?.slice(0, 255) ?? 'FAILED' });
    }
    return adapter.ack('OK');
  }

  /** Browser return: display only (IPN is authoritative). Returns where to send the user. */
  async returnRedirect(entityType: PaymentEntityTypeName, entityId: string): Promise<{ url: string | null; view: CheckoutView }> {
    const view = await this.status(entityType, entityId);
    if (!this.options.appReturnUrl) {
      return { url: null, view };
    }
    const sep = this.options.appReturnUrl.includes('?') ? '&' : '?';
    return {
      url: `${this.options.appReturnUrl}${sep}entityType=${entityType}&entityId=${entityId}&status=${view.status}`,
      view,
    };
  }

  async listIntents(limit = 50, status?: CheckoutIntent['status']) {
    const rows = await this.repo.listIntents({ limit: Math.min(Math.max(limit, 1), 200), status });
    return rows.map((r) => ({
      id: r.id,
      entityType: r.entityType,
      entityId: r.entityId,
      methodCode: r.methodCode,
      provider: r.provider,
      status: r.status,
      amountVnd: r.amountVnd,
      refundedVnd: r.refundedVnd,
      providerRef: r.providerRef,
      failureReason: r.failureReason,
      updatedAt: r.updatedAt.toISOString(),
    }));
  }

  /** Ops refund of a captured online payment (one refund per intent; full or partial). */
  async refund(input: { intentId: string; amountVnd?: number; reason: string; actorUserId: string; clientIp?: string }) {
    const intent = await this.repo.findById(input.intentId);
    if (!intent) {
      throw paymentError(404, 'PAYMENT_INTENT_NOT_FOUND', 'Payment intent not found');
    }
    if (intent.status !== 'CAPTURED' || intent.refundedVnd > 0) {
      throw paymentError(409, 'PAYMENT_NOT_REFUNDABLE', `Intent is ${intent.status}; only an unrefunded CAPTURED payment can be refunded`);
    }
    const amount = input.amountVnd ?? intent.amountVnd;
    if (!Number.isSafeInteger(amount) || amount <= 0 || amount > intent.amountVnd) {
      throw paymentError(400, 'PAYMENT_REFUND_AMOUNT_INVALID', 'Refund amount must be 1..captured amount');
    }
    const adapter = this.adapterFor(intent.provider);
    let result;
    try {
      result = await adapter.refund({
        providerRef: intent.providerRef ?? '',
        providerTransId: intent.providerTransId,
        providerPayDate: intent.providerPayDate,
        amountVnd: amount,
        capturedAmountVnd: intent.amountVnd,
        reason: input.reason.slice(0, 200) || 'DealGo refund',
        requestId: `RF${Date.now().toString(36)}${randomUUID().replace(/-/g, '').slice(0, 10)}`.toUpperCase(),
        actorRef: input.actorUserId,
        clientIp: input.clientIp || '127.0.0.1',
        now: new Date(),
      });
    } catch (error) {
      if (error instanceof PaymentAdapterError) {
        throw paymentError(502, 'PAYMENT_PROVIDER_ERROR', error.message);
      }
      throw error;
    }
    if (result.status === 'REJECTED') {
      throw paymentError(502, 'PAYMENT_REFUND_REJECTED', result.message ?? 'Refund rejected by provider');
    }
    const updated = await this.repo.update(intent.id, {
      status: result.status === 'PENDING' ? 'REFUND_PENDING' : 'REFUNDED',
      refundedVnd: amount,
    });
    await this.postLedger('PSP_REFUND_RECORDED', intent, amount);
    return { intentId: updated.id, status: updated.status, refundedVnd: amount, providerRefundRef: result.providerRefundRef };
  }

  private adapterFor(provider: PaymentProviderName): PaymentAdapter {
    const adapter = this.adapters[provider];
    if (!adapter || adapter.kind !== 'REAL' || !adapter.isConfigured() || !this.options.publicBaseUrl) {
      throw paymentError(422, 'PAYMENT_METHOD_UNAVAILABLE', `Provider ${provider} is not available`);
    }
    return adapter;
  }

  private async postLedger(
    event: 'PSP_PAYMENT_CAPTURED' | 'PSP_REFUND_RECORDED',
    intent: CheckoutIntent,
    amountVnd: number,
  ) {
    if (!this.ledger) {
      return;
    }
    try {
      await this.ledger.postEvent(event, { entityType: intent.entityType, entityId: intent.entityId, amountVnd });
    } catch (error) {
      // The PSP state is already final; ledger drift is surfaced in logs for reconciliation.
      this.logger.error(`ledger ${event} failed for intent ${intent.id}: ${String(error)}`);
    }
  }

  private cashView(entityType: PaymentEntityTypeName, entityId: string): CheckoutView {
    return {
      entityType,
      entityId,
      methodCode: 'CASH',
      status: 'CASH',
      amountVnd: null,
      paymentUrl: null,
      deeplink: null,
      intentId: null,
      failureReason: null,
    };
  }

  private toView(
    entityType: PaymentEntityTypeName,
    entityId: string,
    methodCode: PaymentMethodCode,
    intent: CheckoutIntent | null,
    now: Date,
  ): CheckoutView {
    const status = toCheckoutStatus(intent, now);
    return {
      entityType,
      entityId,
      methodCode,
      status,
      amountVnd: intent?.amountVnd ?? null,
      paymentUrl: status === 'PENDING' ? intent?.paymentUrl ?? null : null,
      deeplink: status === 'PENDING' ? intent?.deeplink ?? null : null,
      intentId: intent?.id ?? null,
      failureReason: intent?.failureReason ?? null,
    };
  }
}
