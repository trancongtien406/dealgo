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
  createdAt: Date;
  updatedAt: Date;
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
    'status' | 'providerTransId' | 'providerPayDate' | 'refundedVnd' | 'failureReason'
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
  listIntents(query: { limit: number; status?: PaymentIntentStatusName }): Promise<CheckoutIntent[]>;
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

  async listIntents(query: { limit: number; status?: PaymentIntentStatusName }) {
    return [...this.intents.values()]
      .filter((r) => !query.status || r.status === query.status)
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime())
      .slice(0, query.limit)
      .map((r) => ({ ...r }));
  }
}
