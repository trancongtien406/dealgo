import { Injectable, Logger, OnModuleDestroy, OnModuleInit, Optional } from '@nestjs/common';
import { FoodService } from '../../food-order/food.service.js';
import { PaymentStatusBus, type PaymentStatusChange } from '../../payment/checkout/payment-status-bus.js';
import { RideService } from '../../ride/ride.service.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';

type CustomerLookup = { participantRoles(id: string): Promise<{ customerId: string } | null> };

/**
 * Forwards checkout status changes to the job customer's private `user:` room as
 * `paymentStatus` (t50u: replaces the app's 3 s payment poll).
 */
@Injectable()
export class PaymentStatusBridgeService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PaymentStatusBridgeService.name);
  private off: (() => void) | null = null;

  constructor(
    private readonly fanout: SnapshotFanoutService,
    private readonly rides: RideService,
    private readonly food: FoodService,
    @Optional() private readonly bus?: PaymentStatusBus,
  ) {}

  onModuleInit(): void {
    this.off = this.bus?.onChange((change) => this.forward(change)) ?? null;
  }

  onModuleDestroy(): void {
    this.off?.();
    this.off = null;
  }

  async forward(change: PaymentStatusChange): Promise<void> {
    const svc = (change.entityType === 'RIDE' ? this.rides : this.food) as unknown as CustomerLookup;
    const roles = await svc.participantRoles(change.entityId).catch(() => null);
    if (!roles?.customerId) {
      this.logger.debug({ msg: 'payment.status_no_customer', entityType: change.entityType, entityId: change.entityId });
      return;
    }
    this.fanout.emitPaymentStatus(roles.customerId, {
      entityType: change.entityType,
      entityId: change.entityId,
      intentId: change.intentId,
      status: change.status,
      occurredAt: change.occurredAt,
    });
  }
}
