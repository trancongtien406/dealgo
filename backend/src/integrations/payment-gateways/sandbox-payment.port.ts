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
 * Sandbox PaymentPort: persists PaymentIntent rows only.
 * No VNPAY/MOMO capture and no fake online success.
 */
@Injectable()
export class SandboxPaymentPort implements PaymentPort {
  constructor(@Inject(PAYMENT_REPOSITORY) private readonly payments: PaymentRepository) {}

  async createSandboxIntent(input: CreateSandboxIntentInput): Promise<PaymentIntentView> {
    if (!Number.isInteger(input.amountVnd) || input.amountVnd <= 0) {
      throw new UnavailablePaymentError('Sandbox payment amount must be a positive integer VND');
    }
    return this.payments.createSandboxIntent({
      ...input,
      method: input.method ?? 'COD',
    });
  }

  async markCodCollected(input: {
    entityType: PaymentEntityTypeName;
    entityId: string;
  }): Promise<PaymentIntentView> {
    const existing = await this.payments.findByEntity(input.entityType, input.entityId, 'COD');
    if (!existing) {
      throw new UnavailablePaymentError('Sandbox COD payment intent not found');
    }
    // COD intent is recorded via ledger; returns existing payment intent.
    return existing;
  }

  async createRedirectIntent(_input: CreateRedirectIntentInput): Promise<RedirectPaymentIntentView> {
    throw new UnavailablePaymentError(
      'Sandbox provider does not create PSP redirects; set PAYMENT_PROVIDER=vnpay|momo',
    );
  }
}
