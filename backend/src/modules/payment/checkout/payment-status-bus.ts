import { Injectable, Logger } from '@nestjs/common';
import type { PaymentEntityTypeName } from '../payment.constants.js';
import type { CheckoutStatus } from './payment-gateway.service.js';

/** A job's checkout status changed (IPN, reconcile). Hint only: clients re-GET REST. */
export type PaymentStatusChange = {
  entityType: PaymentEntityTypeName;
  entityId: string;
  intentId: string;
  status: CheckoutStatus;
  occurredAt: string;
};

type Listener = (change: PaymentStatusChange) => void | Promise<void>;

/**
 * In-process hook so the realtime layer can push `paymentStatus` without the payment
 * module importing realtime (which imports Ride/Food → Payment). Listener errors never
 * affect the payment write (t50u: replaces the app's 3 s payment poll).
 */
@Injectable()
export class PaymentStatusBus {
  private readonly logger = new Logger(PaymentStatusBus.name);
  private readonly listeners = new Set<Listener>();

  onChange(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  publish(change: PaymentStatusChange): void {
    for (const listener of this.listeners) {
      try {
        void Promise.resolve(listener(change)).catch((error: unknown) => this.warn(error));
      } catch (error) {
        this.warn(error);
      }
    }
  }

  private warn(error: unknown): void {
    this.logger.warn({ msg: 'payment.status_listener_failed', error: error instanceof Error ? error.message : 'unknown' });
  }
}
