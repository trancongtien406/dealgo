import type {
  PaymentEntityTypeName,
  PaymentIntentStatusName,
  PaymentMethodName,
  PaymentProviderName,
} from './payment.constants.js';

export type PaymentIntentView = {
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
  createdAt: string;
};

export type CreateSandboxIntentInput = {
  entityType: PaymentEntityTypeName;
  entityId: string;
  amountVnd: number;
  method?: PaymentMethodName;
};

export type CreateRedirectIntentInput = {
  entityType: PaymentEntityTypeName;
  entityId: string;
  amountVnd: number;
  returnUrl: string;
  orderInfo?: string;
};

export type RedirectPaymentIntentView = PaymentIntentView & {
  paymentUrl: string;
  providerRef: string;
};

export interface PaymentPort {
  createSandboxIntent(input: CreateSandboxIntentInput): Promise<PaymentIntentView>;
  /** Stub: records that COD was marked collected in sandbox (idempotent no-op beyond intent). */
  markCodCollected(input: {
    entityType: PaymentEntityTypeName;
    entityId: string;
  }): Promise<PaymentIntentView>;
  /**
   * Create a redirect checkout intent (VNPAY/MOMO). Persists CREATED/PENDING_REDIRECT only.
   * Does not claim capture without a verified webhook.
   */
  createRedirectIntent?(input: CreateRedirectIntentInput): Promise<RedirectPaymentIntentView>;
}

export class UnavailablePaymentError extends Error {
  constructor(message = 'Payment provider is not configured') {
    super(message);
    this.name = 'UnavailablePaymentError';
  }
}

export class UnavailablePaymentPort implements PaymentPort {
  async createSandboxIntent(_input: CreateSandboxIntentInput): Promise<PaymentIntentView> {
    throw new UnavailablePaymentError();
  }

  async markCodCollected(_input: {
    entityType: PaymentEntityTypeName;
    entityId: string;
  }): Promise<PaymentIntentView> {
    throw new UnavailablePaymentError();
  }

  async createRedirectIntent(_input: CreateRedirectIntentInput): Promise<RedirectPaymentIntentView> {
    throw new UnavailablePaymentError();
  }
}
