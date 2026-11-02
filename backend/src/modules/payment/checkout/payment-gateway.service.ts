import { PaymentStatusBus } from './payment-status-bus.js';
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
import { RefundKeyConflictError, type CheckoutIntent, type CheckoutRefund, type CheckoutRepository } from './checkout.repository.js';
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

/** What the assigned driver sees: paid online vs cash to collect at the door. */
export type CollectionView = CheckoutView & {
  /** Online amount held by DealGo for this job (captured − refunded). */
  paidOnlineVnd: number;
  /** Cash the driver must collect (job amount − paidOnline, never negative). */
  cashToCollectVnd: number;
};

/** Online vs cash split of a job's amount at completion. Pure. */
export function splitCollection(dueVnd: number, prepaidVnd: number): { onlineVnd: number; cashVnd: number } {
  const due = Math.max(0, Math.trunc(dueVnd));
  const onlineVnd = Math.min(due, Math.max(0, Math.trunc(prepaidVnd)));
  return { onlineVnd, cashVnd: due - onlineVnd };
}

/** Failure reason on an attempt that was abandoned because the job finished in cash. */
export const SUPERSEDED_BY_CASH = 'SUPERSEDED_BY_CASH';
/** Set when a PSP confirms payment after the job already settled in cash (ops must refund). */
export const LATE_CAPTURE_AFTER_CASH = 'LATE_CAPTURE_AFTER_CASH';

const HELD_STATUSES: readonly string[] = ['CAPTURED', 'REFUND_PENDING'];
/** Statuses a PSP capture may still move an intent out of (never CAPTURED/REFUND_*). */
const CAPTURABLE_STATUSES = ['CREATED', 'PENDING_REDIRECT', 'FAILED', 'EXPIRED', 'SANDBOX_RECORDED', 'CAPTURED_STUB'] as const;
/** Statuses a failure callback may still move an intent out of. */
const FAILABLE_STATUSES = ['CREATED', 'PENDING_REDIRECT'] as const;

const PENDING_TTL_MS = 15 * 60 * 1000;
/** Reconciliation gives up waiting for a provider after this and marks the attempt EXPIRED. */
const RECONCILE_GIVE_UP_MS = 2 * 60 * 60 * 1000;

/** Attempt creation time from our order ref (DG{R|F}{base36 ms}{10 hex}); VNPay querydr needs it. */
export function attemptTimeFromRef(ref: string | null, fallback: Date): Date {
  const m = ref ? /^DG[RF]([0-9A-Z]+)[0-9A-F]{10}$/.exec(ref) : null;
  const ms = m ? parseInt(m[1]!.toLowerCase(), 36) : NaN;
  return Number.isFinite(ms) && ms > 1_500_000_000_000 ? new Date(ms) : fallback;
}

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
    @Optional() private readonly statusBus?: PaymentStatusBus,
  ) {}

  /** Push a `paymentStatus` hint after an intent changed state (no client polling). */
  private async notifyStatus(intentId: string): Promise<void> {
    if (!this.statusBus) {
      return;
    }
    try {
      const fresh = await this.repo.findById(intentId);
      if (!fresh) {
        return;
      }
      this.statusBus.publish({
        entityType: fresh.entityType,
        entityId: fresh.entityId,
        intentId: fresh.id,
        status: toCheckoutStatus(fresh),
        occurredAt: new Date().toISOString(),
      });
    } catch {
      // A failed hint never affects the payment; the app re-GETs on reconnect/resume.
    }
  }

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
    // Checks every attempt (not only the latest): a later failed attempt on another method must
    // not let a new attempt overwrite (and re-charge) an intent that already holds money.
    const latest = await this.repo.latestForEntity(input.entityType, input.entityId);
    const held = (await this.repo.listIntents({ limit: 20, q: input.entityId })).find(
      (r) => r.entityType === input.entityType && r.entityId === input.entityId && HELD_STATUSES.includes(r.status),
    );
    const paid = held ?? (latest && latest.status === 'REFUNDED' ? latest : null);
    if (paid) {
      const paidCode = (paid.methodCode as PaymentMethodCode | null) ?? code;
      return this.toView(input.entityType, input.entityId, paidCode, paid, now);
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
      await this.applyCapture(intent, cb.providerTransId, cb.providerPayDate);
    } else {
      await this.repo.transition(intent.id, FAILABLE_STATUSES, {
        status: 'FAILED',
        failureReason: cb.failureReason?.slice(0, 255) ?? 'FAILED',
      });
    }
    await this.notifyStatus(intent.id);
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

  async listIntents(
    limit = 50,
    status?: CheckoutIntent['status'],
    filter: { provider?: PaymentProviderName; entityType?: PaymentEntityTypeName; q?: string } = {},
  ) {
    const rows = await this.repo.listIntents({
      limit: Math.min(Math.max(limit, 1), 200),
      status,
      provider: filter.provider,
      entityType: filter.entityType,
      q: filter.q?.trim() || undefined,
    });
    return rows.map((r) => this.opsRow(r));
  }

  /** Intent + refund history for the ops detail page. */
  async intentDetail(id: string) {
    const intent = await this.repo.findById(id);
    if (!intent) {
      throw paymentError(404, 'PAYMENT_INTENT_NOT_FOUND', 'Payment intent not found');
    }
    const refunds = await this.repo.listRefunds(id);
    return {
      ...this.opsRow(intent),
      providerTransId: intent.providerTransId,
      providerPayDate: intent.providerPayDate,
      createdAt: intent.createdAt.toISOString(),
      settledAt: intent.settledAt?.toISOString() ?? null,
      lastReconciledAt: intent.lastReconciledAt?.toISOString() ?? null,
      reconcileAttempts: intent.reconcileAttempts,
      refundableVnd: this.refundableVnd(intent),
      refunds: refunds.map((r) => this.refundRow(r)),
    };
  }

  /**
   * Ops refund of a captured online payment. Supports several partial refunds; the running total
   * can never exceed the captured amount (atomic reservation). Each refund gets its own journal.
   */
  async refund(input: {
    intentId: string;
    amountVnd?: number;
    reason: string;
    actorUserId: string;
    clientIp?: string;
    /** Same key → same refund (double submit / network retry never refunds twice). */
    idempotencyKey?: string;
  }) {
    const intent = await this.repo.findById(input.intentId);
    if (!intent) {
      throw paymentError(404, 'PAYMENT_INTENT_NOT_FOUND', 'Payment intent not found');
    }
    const key = input.idempotencyKey?.trim().slice(0, 64) || null;
    if (key) {
      const prior = await this.repo.findRefundByKey(key);
      if (prior) {
        return this.refundReplay(intent, prior);
      }
    }
    if (!HELD_STATUSES.includes(intent.status)) {
      throw paymentError(409, 'PAYMENT_NOT_REFUNDABLE', `Intent is ${intent.status}; only a CAPTURED payment can be refunded`);
    }
    const remaining = this.refundableVnd(intent);
    const amount = input.amountVnd ?? remaining;
    if (!Number.isSafeInteger(amount) || amount <= 0 || amount > remaining) {
      throw paymentError(400, 'PAYMENT_REFUND_AMOUNT_INVALID', `Refund amount must be 1..${remaining} VND`);
    }
    if (!(await this.repo.reserveRefund(intent.id, amount))) {
      throw paymentError(409, 'PAYMENT_REFUND_EXCEEDS_CAPTURED', 'Refunds would exceed the captured amount');
    }
    const adapter = this.adapterFor(intent.provider);
    const now = new Date();
    const requestId = `RF${now.getTime().toString(36)}${randomUUID().replace(/-/g, '').slice(0, 10)}`.toUpperCase();
    const reason = input.reason.slice(0, 200) || 'DealGo refund';
    // Read after the reservation: a completion holding the intent lock has committed by now.
    const settled = (await this.repo.findById(intent.id))?.settledAt ?? intent.settledAt;
    let row: CheckoutRefund;
    try {
      row = await this.repo.createRefund({
        paymentIntentId: intent.id,
        amountVnd: amount,
        status: 'PENDING',
        requestId,
        idempotencyKey: key,
        providerRefundRef: null,
        reason,
        actorUserId: input.actorUserId,
        afterSettlement: settled !== null,
      });
    } catch (error) {
      if (error instanceof RefundKeyConflictError && key) {
        // A concurrent submission with the same key won the insert: undo our reservation.
        await this.repo.releaseRefund(intent.id, amount);
        const prior = await this.repo.findRefundByKey(key);
        if (prior) {
          return this.refundReplay((await this.repo.findById(intent.id)) ?? intent, prior);
        }
      }
      throw error;
    }
    let result;
    try {
      result = await adapter.refund({
        providerRef: intent.providerRef ?? '',
        providerTransId: intent.providerTransId,
        providerPayDate: intent.providerPayDate,
        amountVnd: amount,
        capturedAmountVnd: intent.amountVnd,
        reason,
        requestId,
        actorRef: input.actorUserId,
        clientIp: input.clientIp || '127.0.0.1',
        now,
      });
    } catch (error) {
      await this.repo.releaseRefund(intent.id, amount);
      await this.repo.updateRefund(row.id, { status: 'REJECTED' });
      if (error instanceof PaymentAdapterError) {
        throw paymentError(502, 'PAYMENT_PROVIDER_ERROR', error.message);
      }
      throw error;
    }
    if (result.status === 'REJECTED') {
      await this.repo.releaseRefund(intent.id, amount);
      await this.repo.updateRefund(row.id, { status: 'REJECTED', providerRefundRef: result.providerRefundRef });
      throw paymentError(502, 'PAYMENT_REFUND_REJECTED', result.message ?? 'Refund rejected by provider');
    }
    const refund = await this.repo.updateRefund(row.id, {
      status: result.status === 'PENDING' ? 'PENDING' : 'SUCCEEDED',
      providerRefundRef: result.providerRefundRef,
    });
    const after = (await this.repo.findById(intent.id))!;
    const fully = after.refundedVnd >= after.amountVnd;
    const updated = await this.repo.update(intent.id, {
      status: fully ? (refund.status === 'PENDING' ? 'REFUND_PENDING' : 'REFUNDED') : after.status,
    });
    await this.postRefundLedger(refund);
    await this.notifyStatus(updated.id);
    return {
      intentId: updated.id,
      status: updated.status,
      refundedVnd: updated.refundedVnd,
      refundableVnd: this.refundableVnd(updated),
      refund: this.refundRow(refund),
    };
  }

  private refundReplay(intent: CheckoutIntent, prior: CheckoutRefund) {
    if (prior.paymentIntentId !== intent.id) {
      throw paymentError(409, 'PAYMENT_REFUND_KEY_REUSED', 'Idempotency key was used for another payment');
    }
    return {
      intentId: intent.id,
      status: intent.status,
      refundedVnd: intent.refundedVnd,
      refundableVnd: this.refundableVnd(intent),
      refund: this.refundRow(prior),
      replayed: true as const,
    };
  }

  /**
   * FOOD-002: the job was cancelled after the customer paid online → refund what DealGo still
   * holds, in full. Driven by the job's CANCELLED status outbox row (retried until it succeeds);
   * the per-intent idempotency key makes a replayed row a no-op. Settled intents are skipped.
   */
  async refundOnCancel(entityType: PaymentEntityTypeName, entityId: string, actorUserId: string) {
    const rows = await this.repo.listIntents({ limit: 20, q: entityId });
    const results: Array<{ intentId: string; refundId: string; status: string; replayed: boolean }> = [];
    for (const intent of rows.filter((r) => r.entityType === entityType && r.entityId === entityId)) {
      const key = `auto-cancel:${intent.id}`;
      const prior = await this.repo.findRefundByKey(key);
      if (!prior && (!HELD_STATUSES.includes(intent.status) || intent.settledAt || this.refundableVnd(intent) <= 0)) {
        continue;
      }
      const r = await this.refund({
        intentId: intent.id,
        reason: `Tự động hoàn tiền: ${entityType === 'RIDE' ? 'chuyến' : 'đơn'} đã huỷ`,
        actorUserId,
        idempotencyKey: key,
      });
      results.push({ intentId: intent.id, refundId: r.refund.id, status: r.refund.status, replayed: 'replayed' in r });
    }
    return results;
  }

  /** Online amount DealGo holds for the job and has not yet applied to a completion. */
  async prepaidFor(entityType: PaymentEntityTypeName, entityId: string): Promise<{ intentId: string; amountVnd: number } | null> {
    const latest = await this.repo.latestForEntity(entityType, entityId);
    if (!latest || !HELD_STATUSES.includes(latest.status) || latest.settledAt) {
      return null;
    }
    const held = latest.amountVnd - latest.refundedVnd;
    return held > 0 ? { intentId: latest.id, amountVnd: held } : null;
  }

  /**
   * FOOD-003 / MONEY-003: prepaid amount re-read inside the completion transaction (intent rows
   * locked), so a refund racing the completion either lands first (smaller prepaid, more cash) or
   * waits and is booked as an after-settlement refund. Pair with {@link settleWithin}.
   */
  async prepaidWithin(tx: unknown, entityType: PaymentEntityTypeName, entityId: string): Promise<{ intentId: string; amountVnd: number } | null> {
    const latest = await this.repo.latestForEntityWithin(tx, entityType, entityId);
    if (!latest || !HELD_STATUSES.includes(latest.status) || latest.settledAt) {
      return null;
    }
    const held = latest.amountVnd - latest.refundedVnd;
    return held > 0 ? { intentId: latest.id, amountVnd: held } : null;
  }

  /** Marks the applied prepayment settled in the same transaction as the completion journals. */
  async settleWithin(tx: unknown, intentId: string, at = new Date()) {
    await this.repo.settleWithin(tx, intentId, at);
  }

  /**
   * After a job completes: marks the applied prepayment settled, or (cash completion) retires
   * any still-pending online attempt so a late PSP capture is flagged for refund.
   */
  async afterCompletion(entityType: PaymentEntityTypeName, entityId: string, appliedIntentId: string | null, at = new Date()) {
    const rows = await this.repo.listIntents({ limit: 20, q: entityId });
    for (const row of rows.filter((r) => r.entityType === entityType && r.entityId === entityId)) {
      if (row.id === appliedIntentId) {
        await this.repo.update(row.id, { settledAt: at });
      } else if (row.status === 'PENDING_REDIRECT' || row.status === 'CREATED') {
        // Conditional: a capture racing this completion wins and is flagged as a late capture.
        await this.repo.transition(row.id, FAILABLE_STATUSES, { status: 'EXPIRED', failureReason: SUPERSEDED_BY_CASH });
      }
    }
  }

  /** Driver-facing payment info for an assigned job. */
  async collection(entityType: PaymentEntityTypeName, entityId: string, dueVnd: number, settledOnlineVnd?: number): Promise<CollectionView> {
    const view = await this.status(entityType, entityId);
    const latest = await this.repo.latestForEntity(entityType, entityId);
    const held =
      settledOnlineVnd ??
      (latest && HELD_STATUSES.includes(latest.status) && latest.failureReason !== LATE_CAPTURE_AFTER_CASH
        ? latest.amountVnd - latest.refundedVnd
        : 0);
    const split = splitCollection(dueVnd, held);
    return { ...view, paidOnlineVnd: split.onlineVnd, cashToCollectVnd: split.cashVnd };
  }

  /**
   * Active reconciliation: asks the PSP for the truth on attempts stuck pending (missed IPN).
   * Idempotent: captures go through the same path as callbacks (event dedupe + ledger unique key).
   */
  async reconcilePending(now = new Date(), opts: { olderThanMs?: number; limit?: number; maxAttempts?: number } = {}) {
    const candidates = await this.repo.pendingForReconcile({
      olderThan: new Date(now.getTime() - (opts.olderThanMs ?? 2 * 60 * 1000)),
      limit: opts.limit ?? 50,
      maxAttempts: opts.maxAttempts ?? 30,
    });
    const summary = { checked: 0, captured: 0, failed: 0, expired: 0, pending: 0, skipped: 0 };
    for (const intent of candidates) {
      const adapter = this.adapters[intent.provider];
      if (!adapter || adapter.kind !== 'REAL' || !adapter.isConfigured() || !intent.providerRef) {
        summary.skipped += 1;
        continue;
      }
      summary.checked += 1;
      const bump = { lastReconciledAt: now, reconcileAttempts: intent.reconcileAttempts + 1 };
      let result;
      try {
        result = await adapter.query({
          providerRef: intent.providerRef,
          attemptedAt: attemptTimeFromRef(intent.providerRef, intent.createdAt),
          requestId: `RQ${now.getTime().toString(36)}${randomUUID().replace(/-/g, '').slice(0, 10)}`.toUpperCase(),
          clientIp: '127.0.0.1',
          now,
        });
      } catch (error) {
        this.logger.warn(`reconcile query failed for ${intent.id}: ${String(error)}`);
        await this.repo.update(intent.id, bump);
        summary.pending += 1;
        continue;
      }
      if (result.state === 'CAPTURED') {
        if (result.amountVnd !== null && result.amountVnd !== intent.amountVnd) {
          await this.repo.update(intent.id, { ...bump, failureReason: 'RECONCILE_AMOUNT_MISMATCH' });
          summary.skipped += 1;
          continue;
        }
        const fresh = await this.repo.recordEvent(
          intent.provider,
          `reconcile:${intent.providerRef}:${result.providerTransId ?? ''}`,
          intent.id,
          'CAPTURED',
        );
        const current = await this.repo.findById(intent.id);
        if (fresh && current && !HELD_STATUSES.includes(current.status) && current.status !== 'REFUNDED') {
          await this.applyCapture(current, result.providerTransId, result.providerPayDate);
        }
        await this.repo.update(intent.id, bump);
        await this.notifyStatus(intent.id);
        summary.captured += 1;
      } else if (result.state === 'FAILED') {
        await this.repo.transition(intent.id, FAILABLE_STATUSES, { status: 'FAILED', failureReason: result.message ?? 'FAILED' });
        await this.repo.update(intent.id, bump);
        await this.notifyStatus(intent.id);
        summary.failed += 1;
      } else if (now.getTime() - intent.updatedAt.getTime() > RECONCILE_GIVE_UP_MS) {
        await this.repo.transition(intent.id, FAILABLE_STATUSES, { status: 'EXPIRED', failureReason: 'RECONCILE_TIMEOUT' });
        await this.repo.update(intent.id, bump);
        await this.notifyStatus(intent.id);
        summary.expired += 1;
      } else {
        await this.repo.update(intent.id, bump);
        summary.pending += 1;
      }
    }
    return summary;
  }

  private async applyCapture(intent: CheckoutIntent, providerTransId: string | null, providerPayDate: string | null) {
    // An attempt retired because the job finished in cash: keep the money trail, flag for refund.
    // Re-read: a concurrent completion may have retired the attempt since the caller looked.
    const current = (await this.repo.findById(intent.id)) ?? intent;
    const late = current.status === 'EXPIRED' && current.failureReason === SUPERSEDED_BY_CASH;
    const moved = await this.repo.transition(current.id, CAPTURABLE_STATUSES, {
      status: 'CAPTURED',
      providerTransId,
      providerPayDate,
      failureReason: late ? LATE_CAPTURE_AFTER_CASH : null,
    });
    if (!moved) {
      // Already CAPTURED / refunded by a concurrent callback or reconcile: never re-journal.
      return;
    }
    await this.postLedger('PSP_PAYMENT_CAPTURED', current, current.amountVnd);
    if (late) {
      this.logger.warn(`late capture after cash completion: intent ${intent.id} must be refunded`);
    }
  }

  private refundableVnd(intent: CheckoutIntent): number {
    return HELD_STATUSES.includes(intent.status) ? Math.max(0, intent.amountVnd - intent.refundedVnd) : 0;
  }

  private refundRow(r: CheckoutRefund) {
    return {
      id: r.id,
      amountVnd: r.amountVnd,
      status: r.status,
      requestId: r.requestId,
      providerRefundRef: r.providerRefundRef,
      reason: r.reason,
      actorUserId: r.actorUserId,
      afterSettlement: r.afterSettlement,
      createdAt: r.createdAt.toISOString(),
    };
  }

  private opsRow(r: CheckoutIntent) {
    return {
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
      settled: r.settledAt !== null,
      updatedAt: r.updatedAt.toISOString(),
    };
  }

  private async postRefundLedger(refund: CheckoutRefund) {
    if (!this.ledger) {
      return;
    }
    const event = refund.afterSettlement ? 'PSP_REFUND_AFTER_SETTLEMENT' : 'PSP_REFUND_RECORDED';
    try {
      await this.ledger.postEvent(event, { entityType: 'PAYMENT_REFUND', entityId: refund.id, amountVnd: refund.amountVnd });
    } catch (error) {
      this.logger.error(`ledger ${event} failed for refund ${refund.id}: ${String(error)}`);
    }
  }

  private adapterFor(provider: PaymentProviderName): PaymentAdapter {
    const adapter = this.adapters[provider];
    if (!adapter || adapter.kind !== 'REAL' || !adapter.isConfigured() || !this.options.publicBaseUrl) {
      throw paymentError(422, 'PAYMENT_METHOD_UNAVAILABLE', `Provider ${provider} is not available`);
    }
    return adapter;
  }

  private async postLedger(
    event: 'PSP_PAYMENT_CAPTURED',
    intent: CheckoutIntent,
    amountVnd: number,
  ) {
    if (!this.ledger) {
      return;
    }
    try {
      // One capture journal per intent (not per job): a second online payment for the same job
      // (another method) is journaled too, so PSP clearing matches what the providers hold.
      await this.ledger.postEvent(event, { entityType: 'PAYMENT_INTENT', entityId: intent.id, amountVnd });
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
