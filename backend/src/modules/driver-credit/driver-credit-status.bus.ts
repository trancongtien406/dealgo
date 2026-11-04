import { Injectable, Logger } from '@nestjs/common';
import type { DriverTopUpStatusName } from './driver-credit.repository.js';

/**
 * A driver's prepaid top-up changed state (IPN, reconcile, cancel, refund). The app
 * re-GETs `GET /v1/driver/credit` and the top-up; this is only a hint.
 */
export type DriverCreditStatusChange = {
  driverId: string;
  topUpId: string;
  status: DriverTopUpStatusName;
  occurredAt: string;
};

type Listener = (change: DriverCreditStatusChange) => void | Promise<void>;

/**
 * In-process hook so the realtime layer can push `driverCreditStatus` without the
 * driver-credit module importing realtime.
 */
@Injectable()
export class DriverCreditStatusBus {
  private readonly logger = new Logger(DriverCreditStatusBus.name);
  private readonly listeners = new Set<Listener>();

  onChange(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  publish(change: DriverCreditStatusChange): void {
    for (const listener of this.listeners) {
      try {
        void Promise.resolve(listener(change)).catch((error: unknown) => this.warn(error));
      } catch (error) {
        this.warn(error);
      }
    }
  }

  private warn(error: unknown): void {
    this.logger.warn({
      msg: 'driver_credit.status_listener_failed',
      error: error instanceof Error ? error.message : 'unknown',
    });
  }
}
