import { randomUUID } from 'node:crypto';
import type {
  PaymentEntityTypeName,
  PaymentIntentStatusName,
  PaymentMethodName,
  PaymentProviderName,
} from './payment.constants.js';
import type {
  CreateRedirectIntentInput,
  CreateSandboxIntentInput,
  PaymentIntentView,
  RedirectPaymentIntentView,
} from './payment-port.js';

export type PersistRedirectIntentInput = CreateRedirectIntentInput & {
  method: 'VNPAY' | 'MOMO';
  provider: 'vnpay' | 'momo';
  providerRef: string;
  paymentUrl: string;
  status?: 'CREATED' | 'PENDING_REDIRECT';
};

export type WebhookRecordInput = {
  provider: 'vnpay' | 'momo';
  providerEventId: string;
  providerRef?: string;
  markStatus: 'SANDBOX_RECORDED' | 'CAPTURED_STUB';
};

export type WebhookRecordResult = {
  duplicate: boolean;
  intent: PaymentIntentView | null;
};

export interface PaymentRepository {
  createSandboxIntent(input: CreateSandboxIntentInput): Promise<PaymentIntentView>;
  createRedirectIntent(input: PersistRedirectIntentInput): Promise<RedirectPaymentIntentView>;
  findByEntity(
    entityType: PaymentEntityTypeName,
    entityId: string,
    method?: PaymentMethodName,
  ): Promise<PaymentIntentView | null>;
  findByProviderRef(
    provider: PaymentProviderName,
    providerRef: string,
  ): Promise<PaymentIntentView | null>;
  recordWebhook(input: WebhookRecordInput): Promise<WebhookRecordResult>;
}

type StoredIntent = {
  id: string;
  entityType: PaymentEntityTypeName;
  entityId: string;
  method: PaymentMethodName;
  status: PaymentIntentStatusName;
  amountVnd: number;
  currency: 'VND';
  provider: PaymentProviderName;
  providerRef: string | null;
  paymentUrl: string | null;
  createdAt: Date;
};

export class MemoryPaymentRepository implements PaymentRepository {
  private readonly intents = new Map<string, StoredIntent>();
  private readonly webhooks = new Set<string>();
  private tail: Promise<void> = Promise.resolve();

  createSandboxIntent(input: CreateSandboxIntentInput): Promise<PaymentIntentView> {
    return this.run(() => {
      const method = input.method ?? 'COD';
      const key = intentKey(input.entityType, input.entityId, method);
      const existing = this.intents.get(key);
      if (existing) {
        return toView(existing);
      }
      const created: StoredIntent = {
        id: randomUUID(),
        entityType: input.entityType,
        entityId: input.entityId,
        method,
        status: 'SANDBOX_RECORDED',
        amountVnd: input.amountVnd,
        currency: 'VND',
        provider: 'sandbox',
        providerRef: null,
        paymentUrl: null,
        createdAt: new Date(),
      };
      this.intents.set(key, created);
      return toView(created);
    });
  }

  createRedirectIntent(input: PersistRedirectIntentInput): Promise<RedirectPaymentIntentView> {
    return this.run(() => {
      const key = intentKey(input.entityType, input.entityId, input.method);
      const existing = this.intents.get(key);
      if (existing && existing.paymentUrl && existing.providerRef) {
        return toRedirectView(existing);
      }
      const created: StoredIntent = {
        id: existing?.id ?? randomUUID(),
        entityType: input.entityType,
        entityId: input.entityId,
        method: input.method,
        status: input.status ?? 'PENDING_REDIRECT',
        amountVnd: input.amountVnd,
        currency: 'VND',
        provider: input.provider,
        providerRef: input.providerRef,
        paymentUrl: input.paymentUrl,
        createdAt: existing?.createdAt ?? new Date(),
      };
      this.intents.set(key, created);
      return toRedirectView(created);
    });
  }

  findByEntity(
    entityType: PaymentEntityTypeName,
    entityId: string,
    method: PaymentMethodName = 'COD',
  ): Promise<PaymentIntentView | null> {
    return this.run(() => {
      const intent = this.intents.get(intentKey(entityType, entityId, method));
      return intent ? toView(intent) : null;
    });
  }

  findByProviderRef(
    provider: PaymentProviderName,
    providerRef: string,
  ): Promise<PaymentIntentView | null> {
    return this.run(() => {
      for (const intent of this.intents.values()) {
        if (intent.provider === provider && intent.providerRef === providerRef) {
          return toView(intent);
        }
      }
      return null;
    });
  }

  recordWebhook(input: WebhookRecordInput): Promise<WebhookRecordResult> {
    return this.run(() => {
      const eventKey = `${input.provider}:${input.providerEventId}`;
      if (this.webhooks.has(eventKey)) {
        const intent = input.providerRef
          ? [...this.intents.values()].find(
              (row) => row.provider === input.provider && row.providerRef === input.providerRef,
            )
          : undefined;
        return { duplicate: true, intent: intent ? toView(intent) : null };
      }
      this.webhooks.add(eventKey);
      let intent: StoredIntent | undefined;
      if (input.providerRef) {
        intent = [...this.intents.values()].find(
          (row) => row.provider === input.provider && row.providerRef === input.providerRef,
        );
        if (intent) {
          intent.status = input.markStatus;
        }
      }
      return { duplicate: false, intent: intent ? toView(intent) : null };
    });
  }

  private run<T>(work: () => T): Promise<T> {
    const execute = this.tail.then(() => work());
    this.tail = execute.then(
      () => undefined,
      () => undefined,
    );
    return execute;
  }
}

function intentKey(
  entityType: PaymentEntityTypeName,
  entityId: string,
  method: PaymentMethodName,
): string {
  return `${entityType}:${entityId}:${method}`;
}

function toView(intent: StoredIntent): PaymentIntentView {
  return {
    id: intent.id,
    entityType: intent.entityType,
    entityId: intent.entityId,
    method: intent.method,
    status: intent.status,
    amountVnd: intent.amountVnd,
    currency: intent.currency,
    provider: intent.provider,
    providerRef: intent.providerRef,
    paymentUrl: intent.paymentUrl,
    createdAt: intent.createdAt.toISOString(),
  };
}

function toRedirectView(intent: StoredIntent): RedirectPaymentIntentView {
  if (!intent.paymentUrl || !intent.providerRef) {
    throw new Error('Redirect intent missing paymentUrl/providerRef');
  }
  return {
    ...toView(intent),
    paymentUrl: intent.paymentUrl,
    providerRef: intent.providerRef,
  };
}
