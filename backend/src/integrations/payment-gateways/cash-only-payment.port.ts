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

/**
 * DEC-PROD-050: PAYMENT_PROVIDER=cash-only. Production-safe COD-only launch: records COD intents
 * (the ledger stays the source of the COD obligation) and refuses every online/PSP path.
 */
@Injectable()
export class CashOnlyPaymentPort implements PaymentPort {
  constructor(@Inject(PAYMENT_REPOSITORY) private readonly payments: PaymentRepository) {}

  async createSandboxIntent(input: CreateSandboxIntentInput): Promise<PaymentIntentView> {
    const method = input.method ?? 'COD';
    if (method !== 'COD') {
      throw new UnavailablePaymentError('Online payment is disabled (cash-only launch)');
    }
    if (!Number.isInteger(input.amountVnd) || input.amountVnd <= 0) {
      throw new UnavailablePaymentError('COD amount must be a positive integer VND');
    }
    return this.payments.createSandboxIntent({ ...input, method });
  }

  async markCodCollected(input: {
    entityType: PaymentEntityTypeName;
    entityId: string;
  }): Promise<PaymentIntentView> {
    const existing = await this.payments.findByEntity(input.entityType, input.entityId, 'COD');
    if (!existing) {
      throw new UnavailablePaymentError('COD payment intent not found');
    }
    return existing;
  }

  async createRedirectIntent(_input: CreateRedirectIntentInput): Promise<RedirectPaymentIntentView> {
    throw new UnavailablePaymentError('Online payment is disabled (cash-only launch)');
  }
}
