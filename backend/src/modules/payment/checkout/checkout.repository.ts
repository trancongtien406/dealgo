import { randomUUID } from 'node:crypto';
import type { PaymentMethodCode } from '../../../platform/settings/payment-method-registry.js';
import type {
  PaymentEntityTypeName,
  PaymentIntentStatusName,
  PaymentMethodName,
  PaymentProviderName,
} from '../payment.constants.js';

export type CheckoutIntent = {
  id: string;
  entityType: PaymentEntityTypeName;
  entityId: string;
  method: PaymentMethodName;
  methodCode: string | null;
  status: PaymentIntentStatusName;
  amountVnd: number;
  provider: PaymentProviderName;
  providerRef: string | null;
  providerTransId: string | null;
  providerPayDate: string | null;
  paymentUrl: string | null;
  deeplink: string | null;
  refundedVnd: number;
  failureReason: string | null;
  settledAt: Date | null;
  lastReconciledAt: Date | null;
  reconcileAttempts: number;
  createdAt: Date;
  updatedAt: Date;
};

export type RefundStatusName = 'PENDING' | 'SUCCEEDED' | 'REJECTED';

export type CheckoutRefund = {
  id: string;
  paymentIntentId: string;
  amountVnd: number;
  status: RefundStatusName;
  requestId: string;
  providerRefundRef: string | null;
  reason: string;
  actorUserId: string;
  afterSettlement: boolean;
  createdAt: Date;
  updatedAt: Date;
};

export type IntentListQuery = {
  limit: number;
  status?: PaymentIntentStatusName;
  provider?: PaymentProviderName;
  entityType?: PaymentEntityTypeName;
  /** Matches intent id, entity id or provider ref (exact). */
  q?: string;
};

export type UpsertAttemptInput = {
  entityType: PaymentEntityTypeName;
  entityId: string;
  method: PaymentMethodName;
  methodCode: PaymentMethodCode;
  provider: PaymentProviderName;
  amountVnd: number;
  providerRef: string;
  paymentUrl: string | null;
  deeplink: string | null;
};

export type IntentPatch = Partial<
  Pick<
    CheckoutIntent,
    | 'status'
    | 'providerTransId'
    | 'providerPayDate'
    | 'refundedVnd'
    | 'failureReason'
    | 'settledAt'
    | 'lastReconciledAt'
    | 'reconcileAttempts'
  >
>;

export interface CheckoutRepository {
  getSelection(entityType: PaymentEntityTypeName, entityId: string): Promise<PaymentMethodCode | null>;
  setSelection(entityType: PaymentEntityTypeName, entityId: string, code: PaymentMethodCode): Promise<void>;
  /** Latest intent for the entity (any method). */
  latestForEntity(entityType: PaymentEntityTypeName, entityId: string): Promise<CheckoutIntent | null>;
  findByEntityMethod(
    entityType: PaymentEntityTypeName,
    entityId: string,
    method: PaymentMethodName,
  ): Promise<CheckoutIntent | null>;
  findById(id: string): Promise<CheckoutIntent | null>;
  findByProviderRef(provider: PaymentProviderName, providerRef: string): Promise<CheckoutIntent | null>;
  /** Creates or replaces (new attempt) the intent row for entity+method. */
  upsertAttempt(input: UpsertAttemptInput): Promise<CheckoutIntent>;
  update(id: string, patch: IntentPatch): Promise<CheckoutIntent>;
  /** Returns false when (provider, eventId) was already recorded (idempotent replay). */
  recordEvent(provider: PaymentProviderName, eventId: string, intentId: string | null, status: string): Promise<boolean>;
  listIntents(query: IntentListQuery): Promise<CheckoutIntent[]>;
  /** Atomically adds `amountVnd` to refundedVnd iff the total stays <= amountVnd captured. */
  reserveRefund(intentId: string, amountVnd: number): Promise<boolean>;
  /** Reverses a reservation (provider rejected / errored). */
  releaseRefund(intentId: string, amountVnd: number): Promise<void>;
  createRefund(input: Omit<CheckoutRefund, 'id' | 'createdAt' | 'updatedAt'>): Promise<CheckoutRefund>;
  updateRefund(id: string, patch: Partial<Pick<CheckoutRefund, 'status' | 'providerRefundRef'>>): Promise<CheckoutRefund>;
  listRefunds(intentId: string): Promise<CheckoutRefund[]>;
  /** Pending online attempts older than `olderThan` (reconciliation candidates). */
  pendingForReconcile(query: { olderThan: Date; limit: number; maxAttempts: number }): Promise<CheckoutIntent[]>;
}

export class MemoryCheckoutRepository implements CheckoutRepository {
  private readonly selections = new Map<string, PaymentMethodCode>();
  private readonly intents = new Map<string, CheckoutIntent>();
  private readonly events = new Set<string>();

  async getSelection(entityType: PaymentEntityTypeName, entityId: string) {
    return this.selections.get(`${entityType}:${entityId}`) ?? null;
  }

  async setSelection(entityType: PaymentEntityTypeName, entityId: string, code: PaymentMethodCode) {
    this.selections.set(`${entityType}:${entityId}`, code);
  }

  async latestForEntity(entityType: PaymentEntityTypeName, entityId: string) {
    const rows = [...this.intents.values()]
      .filter((r) => r.entityType === entityType && r.entityId === entityId)
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
    return rows[0] ? { ...rows[0] } : null;
  }

  async findByEntityMethod(entityType: PaymentEntityTypeName, entityId: string, method: PaymentMethodName) {
    const row = this.intents.get(`${entityType}:${entityId}:${method}`);
    return row ? { ...row } : null;
  }

  async findById(id: string) {
    const row = [...this.intents.values()].find((r) => r.id === id);
    return row ? { ...row } : null;
  }

  async findByProviderRef(provider: PaymentProviderName, providerRef: string) {
    const row = [...this.intents.values()].find(
      (r) => r.provider === provider && r.providerRef === providerRef,
    );
    return row ? { ...row } : null;
  }

  async upsertAttempt(input: UpsertAttemptInput) {
    const key = `${input.entityType}:${input.entityId}:${input.method}`;
    const existing = this.intents.get(key);
    const now = new Date(Math.max(Date.now(), (existing?.updatedAt.getTime() ?? 0) + 1));
    const row: CheckoutIntent = {
      id: existing?.id ?? randomUUID(),
      entityType: input.entityType,
      entityId: input.entityId,
      method: input.method,
      methodCode: input.methodCode,
      status: 'PENDING_REDIRECT',
      amountVnd: input.amountVnd,
      provider: input.provider,
      providerRef: input.providerRef,
      providerTransId: null,
      providerPayDate: null,
      paymentUrl: input.paymentUrl,
      deeplink: input.deeplink,
      refundedVnd: 0,
      failureReason: null,
      settledAt: null,
      lastReconciledAt: null,
      reconcileAttempts: 0,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };
    this.intents.set(key, row);
    return { ...row };
  }

  async update(id: string, patch: IntentPatch) {
    const row = [...this.intents.values()].find((r) => r.id === id);
    if (!row) {
      throw new Error('PAYMENT_INTENT_NOT_FOUND');
    }
    Object.assign(row, patch, { updatedAt: new Date(Math.max(Date.now(), row.updatedAt.getTime() + 1)) });
    return { ...row };
  }

  async recordEvent(provider: PaymentProviderName, eventId: string) {
    const key = `${provider}:${eventId}`;
    if (this.events.has(key)) {
      return false;
    }
    this.events.add(key);
    return true;
  }

  async listIntents(query: IntentListQuery) {
    return [...this.intents.values()]
      .filter((r) => !query.status || r.status === query.status)
      .filter((r) => !query.provider || r.provider === query.provider)
      .filter((r) => !query.entityType || r.entityType === query.entityType)
      .filter((r) => !query.q || [r.id, r.entityId, r.providerRef].includes(query.q))
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime())
      .slice(0, query.limit)
      .map((r) => ({ ...r }));
  }

  private readonly refunds = new Map<string, CheckoutRefund>();

  async reserveRefund(intentId: string, amountVnd: number) {
    const row = [...this.intents.values()].find((r) => r.id === intentId);
    if (!row || row.refundedVnd + amountVnd > row.amountVnd) {
      return false;
    }
    row.refundedVnd += amountVnd;
    return true;
  }

  async releaseRefund(intentId: string, amountVnd: number) {
    const row = [...this.intents.values()].find((r) => r.id === intentId);
    if (row) {
      row.refundedVnd = Math.max(0, row.refundedVnd - amountVnd);
    }
  }

  async createRefund(input: Omit<CheckoutRefund, 'id' | 'createdAt' | 'updatedAt'>) {
    const now = new Date();
    const row: CheckoutRefund = { ...input, id: randomUUID(), createdAt: now, updatedAt: now };
    this.refunds.set(row.id, row);
    return { ...row };
  }

  async updateRefund(id: string, patch: Partial<Pick<CheckoutRefund, 'status' | 'providerRefundRef'>>) {
    const row = this.refunds.get(id);
    if (!row) {
      throw new Error('PAYMENT_REFUND_NOT_FOUND');
    }
    Object.assign(row, patch, { updatedAt: new Date() });
    return { ...row };
  }

  async listRefunds(intentId: string) {
    return [...this.refunds.values()]
      .filter((r) => r.paymentIntentId === intentId)
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
      .map((r) => ({ ...r }));
  }

  async pendingForReconcile(query: { olderThan: Date; limit: number; maxAttempts: number }) {
    return [...this.intents.values()]
      .filter(
        (r) =>
          (r.status === 'PENDING_REDIRECT' || r.status === 'CREATED') &&
          r.updatedAt.getTime() <= query.olderThan.getTime() &&
          r.reconcileAttempts < query.maxAttempts &&
          r.providerRef !== null,
      )
      .sort((a, b) => a.updatedAt.getTime() - b.updatedAt.getTime())
      .slice(0, query.limit)
      .map((r) => ({ ...r }));
  }
}
