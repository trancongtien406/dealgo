import type {
  DriverHistoryWindow,
  CancelInput,
  CreateRideInput,
  DriverLifecycleInput,
  OfferInput,
  OpenRideListing,
  OpsCancelInput,
  OpsReassignInput,
  RideSnapshot,
  SelectInput,
} from './ride-ledger.js';
import { RideLedger } from './ride-ledger.js';
import type { DriverJobCounts } from '../../shared/driver-job-counts.js';
import type { CompletionHook } from '../../shared/tx/completion-hook.js';
import { RideRuleError } from './ride.error.js';
import { VoucherRejectedError, type VoucherRedeemer } from '../promotion/promotion-redemption.js';

export type OpsRidePage = {
  items: RideSnapshot[];
  total: number;
};

export type OpsInterveneResult = {
  ride: RideSnapshot;
  auditId: string;
};

export interface RideRepository {
  create(input: CreateRideInput): Promise<RideSnapshot>;
  findById(id: string, now: Date): Promise<RideSnapshot | null>;
  listOpen(now: Date, limit?: number): Promise<OpenRideListing[]>;
  listPage(
    page: number,
    limit: number,
    now: Date,
    filter?: { status?: string; q?: string; zone?: string; serviceType?: string },
  ): Promise<OpsRidePage>;
  listForCustomer(
    customerId: string,
    page: number,
    limit: number,
    now: Date,
  ): Promise<OpsRidePage>;
  /** COMPLETED/CANCELLED rides still assigned to the driver, newest updatedAt first. */
  listFinishedForDriver(driverId: string, window: DriverHistoryWindow): Promise<RideSnapshot[]>;
  /** Lifetime COMPLETED / terminal ride counts per assigned driver (Admin stats). */
  countFinishedForDrivers(driverIds: readonly string[]): Promise<Map<string, DriverJobCounts>>;
  offer(input: OfferInput): Promise<RideSnapshot>;
  select(input: SelectInput): Promise<RideSnapshot>;
  cancel(input: CancelInput): Promise<RideSnapshot>;
  opsCancel(
    input: OpsCancelInput,
    actorUserId: string,
    reason: string,
  ): Promise<OpsInterveneResult>;
  opsReassign(
    input: OpsReassignInput,
    actorUserId: string,
    reason: string,
  ): Promise<OpsInterveneResult>;
  markEnRoute(input: DriverLifecycleInput): Promise<RideSnapshot>;
  markArrived(input: DriverLifecycleInput): Promise<RideSnapshot>;
  startTrip(input: DriverLifecycleInput): Promise<RideSnapshot>;
  /**
   * `onCompleted` runs inside the completion transaction (ledger + earnings); if it throws,
   * the ride stays IN_PROGRESS.
   */
  complete(input: DriverLifecycleInput, onCompleted?: CompletionHook<RideSnapshot>): Promise<RideSnapshot>;
  expireDue(now: Date, limit?: number): Promise<string[]>;
}

export class MemoryRideRepository implements RideRepository {
  private readonly ledger = new RideLedger();
  private tail: Promise<void> = Promise.resolve();

  constructor(private readonly vouchers?: VoucherRedeemer) {}

  create(input: CreateRideInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.create(input)));
  }

  findById(id: string, now: Date): Promise<RideSnapshot | null> {
    return this.run(() => this.ledger.read(id, now));
  }

  listOpen(now: Date, limit?: number): Promise<OpenRideListing[]> {
    return this.run(() => this.ledger.listOpen(now, limit));
  }

  listPage(
    page: number,
    limit: number,
    now: Date,
    filter?: { status?: string; q?: string; zone?: string; serviceType?: string },
  ): Promise<OpsRidePage> {
    return this.run(() => this.ledger.listPage(page, limit, now, filter));
  }

  listForCustomer(
    customerId: string,
    page: number,
    limit: number,
    now: Date,
  ): Promise<OpsRidePage> {
    return this.run(() => this.ledger.listForCustomer(customerId, page, limit, now));
  }

  listFinishedForDriver(driverId: string, window: DriverHistoryWindow): Promise<RideSnapshot[]> {
    return this.run(() => this.ledger.listFinishedForDriver(driverId, window));
  }

  countFinishedForDrivers(driverIds: readonly string[]): Promise<Map<string, DriverJobCounts>> {
    return this.run(() => this.ledger.countFinishedForDrivers(driverIds));
  }

  offer(input: OfferInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.offer(input)));
  }

  select(input: SelectInput): Promise<RideSnapshot> {
    return this.run(async () => {
      const code = input.voucherCode?.trim();
      const agreed = this.ledger.offerAmount(input.rideId, input.offerId);
      if (!code || agreed === null || this.ledger.hasSelection(input.customerId, input.idempotencyKey)) {
        return finish(this.ledger.select(input));
      }
      if (!this.vouchers) {
        throw new VoucherRejectedError('VOUCHER_NOT_FOUND', `Mã voucher '${code}' không tồn tại.`);
      }
      // Runs are serialized, so redeeming first and releasing on a failed selection is atomic.
      const redeemed = await this.vouchers.redeem({
        code,
        userId: input.customerId,
        entityType: 'RIDE',
        entityId: input.rideId,
        serviceType: 'RIDE',
        orderAmount: agreed,
      });
      const outcome = this.ledger.select(input);
      if (outcome.error || !outcome.ride) {
        await this.vouchers.release({ entityType: 'RIDE', entityId: input.rideId });
        return finish(outcome);
      }
      return (
        this.ledger.applyVoucher(outcome.ride.id, {
          code: redeemed.code,
          discountVnd: redeemed.discountVnd,
          sponsor: redeemed.sponsor,
        }) ?? outcome.ride
      );
    });
  }

  cancel(input: CancelInput): Promise<RideSnapshot> {
    return this.run(async () => {
      const ride = finish(this.ledger.cancel(input));
      await this.vouchers?.release({ entityType: 'RIDE', entityId: ride.id });
      return ride;
    });
  }

  opsCancel(
    input: OpsCancelInput,
    _actorUserId: string,
    _reason: string,
  ): Promise<OpsInterveneResult> {
    return this.run(async () => {
      const ride = finish(this.ledger.opsCancel(input));
      await this.vouchers?.release({ entityType: 'RIDE', entityId: ride.id });
      return { ride, auditId: `memory-audit-${ride.id}-cancel` };
    });
  }

  opsReassign(
    input: OpsReassignInput,
    _actorUserId: string,
    _reason: string,
  ): Promise<OpsInterveneResult> {
    return this.run(async () => {
      const ride = finish(this.ledger.opsReassign(input));
      await this.vouchers?.release({ entityType: 'RIDE', entityId: ride.id });
      return { ride, auditId: `memory-audit-${ride.id}-reassign` };
    });
  }

  markEnRoute(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.markEnRoute(input)));
  }

  markArrived(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.markArrived(input)));
  }

  startTrip(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.startTrip(input)));
  }

  complete(
    input: DriverLifecycleInput,
    onCompleted?: CompletionHook<RideSnapshot>,
  ): Promise<RideSnapshot> {
    // Memory mode (tests/dev) has no rollback; Prisma mode is transactional.
    return this.run(() => finish(this.ledger.complete(input))).then(async (ride) => {
      await onCompleted?.(null, ride);
      return ride;
    });
  }

  expireDue(now: Date, limit?: number): Promise<string[]> {
    return this.run(() => {
      const expired = this.ledger.expireDue(now);
      if (limit !== undefined && limit > 0) {
        return expired.slice(0, limit);
      }
      return expired;
    });
  }

  private run<T>(work: () => T | Promise<T>): Promise<T> {
    const execute = this.tail.then(() => work());
    this.tail = execute.then(
      () => undefined,
      () => undefined,
    );
    return execute;
  }
}

function finish(outcome: { error?: RideRuleError['code']; ride?: RideSnapshot }): RideSnapshot {
  if (outcome.error || !outcome.ride) {
    throw new RideRuleError(outcome.error ?? 'RIDE_NOT_FOUND');
  }
  return outcome.ride;
}
