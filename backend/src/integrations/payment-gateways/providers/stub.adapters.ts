import type { PaymentProviderName } from '../../../modules/payment/payment.constants.js';
import {
  PaymentAdapterError,
  type AdapterCallback,
  type AdapterCreateResult,
  type AdapterQueryResult,
  type AdapterRefundResult,
  type CallbackAck,
  type PaymentAdapter,
} from './payment-adapter.js';

/**
 * STUB adapter — NOT a real integration. Used for ShopeePay, international card (Visa/Master/JCB
 * via a card gateway), Apple Pay and the DealGo wallet until contracts + licences exist.
 * The registry never makes a STUB method selectable, so the system keeps running on cash.
 */
export class StubPaymentAdapter implements PaymentAdapter {
  readonly kind = 'STUB' as const;

  constructor(
    readonly provider: PaymentProviderName,
    private readonly envKeys: readonly string[],
    private readonly label: string,
  ) {}

  requiredEnv(): readonly string[] {
    return this.envKeys;
  }

  isConfigured(): boolean {
    return false;
  }

  async create(): Promise<AdapterCreateResult> {
    throw new PaymentAdapterError('ADAPTER_STUB', `${this.label} adapter is a stub (not integrated)`);
  }

  verifyCallback(): AdapterCallback {
    return {
      valid: false,
      providerRef: null,
      providerEventId: null,
      success: false,
      amountVnd: null,
      providerTransId: null,
      providerPayDate: null,
      failureReason: 'STUB',
    };
  }

  ack(): CallbackAck {
    return { httpStatus: 501, body: { message: `${this.label} is not integrated` } };
  }

  async refund(): Promise<AdapterRefundResult> {
    throw new PaymentAdapterError('ADAPTER_STUB', `${this.label} adapter is a stub (not integrated)`);
  }

  async query(): Promise<AdapterQueryResult> {
    throw new PaymentAdapterError('ADAPTER_STUB', `${this.label} adapter is a stub (not integrated)`);
  }
}
