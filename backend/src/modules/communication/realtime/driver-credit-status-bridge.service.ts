import { Injectable, OnModuleDestroy, OnModuleInit, Optional } from '@nestjs/common';
import {
  DriverCreditStatusBus,
  type DriverCreditStatusChange,
} from '../../driver-credit/driver-credit-status.bus.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';

/**
 * Forwards driver prepayment changes to the driver's private `user:` room as
 * `driverCreditStatus`. The app re-GETs `GET /v1/driver/credit` and the top-up.
 */
@Injectable()
export class DriverCreditStatusBridgeService implements OnModuleInit, OnModuleDestroy {
  private off: (() => void) | null = null;

  constructor(
    private readonly fanout: SnapshotFanoutService,
    @Optional() private readonly bus?: DriverCreditStatusBus,
  ) {}

  onModuleInit(): void {
    this.off = this.bus?.onChange((change) => this.forward(change)) ?? null;
  }

  onModuleDestroy(): void {
    this.off?.();
    this.off = null;
  }

  forward(change: DriverCreditStatusChange): void {
    this.fanout.emitDriverCreditStatus(change.driverId, {
      topUpId: change.topUpId,
      status: change.status,
      occurredAt: change.occurredAt,
    });
  }
}
