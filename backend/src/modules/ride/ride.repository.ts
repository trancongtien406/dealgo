import type { GeoBox } from '../dispatch/dispatch-filter.js';
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
  RaiseFareInput,
  SetAutoAcceptInput,
  DeclineOfferInput,
  WithdrawOfferInput,
  DriverCancelInput,
  NoShowInput,
  RideTimeoutPolicy,
  StopEventInput,
  UpdateStopsInput,
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

/**
 * Extra rows written atomically with a new ride (DEC-PROD-071 parcel row). `tx` is the
 * repository's transaction handle (Prisma tx; undefined in memory). Runs on idempotent
 * replays too, so it must be idempotent; a throw rolls the ride back.
 */
export type RideCreateHook = (ctx: { tx: unknown; rideId: string }) => Promise<void>;

export interface RideRepository {
  create(input: CreateRideInput, withinCreate?: RideCreateHook): Promise<RideSnapshot>;
  findById(id: string, now: Date): Promise<RideSnapshot | null>;
  /** t82u: priced road distance shown to drivers (stored beside the ride, outside the ledger). */
  setRouteDistanceKm?(rideId: string, km: number): Promise<void>;
  routeDistanceKm?(rideId: string): Promise<number | null>;
  /** `area`: only rides whose pickup is inside this box (DB-side pre-filter). */
  listOpen(
    now: Date,
    limit?: number,
    vehicleClassCode?: string,
    area?: GeoBox,
  ): Promise<OpenRideListing[]>;
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
  /** Ride ids assigned to the driver in one of [statuses] (live location fan-out). */
  listIdsForDriverInStatuses?(driverId: string, statuses: readonly string[]): Promise<string[]>;
  /** Customer's ride ids in one of [statuses], newest first (relaunch resume, DEC-PROD-057). */
  listIdsForCustomerInStatuses?(customerId: string, statuses: readonly string[]): Promise<string[]>;
  /** Times of customer cancellations after a driver was assigned, since `since`. */
  customerCancelTimes(customerId: string, since: Date): Promise<Date[]>;
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
  /** Customer raises the bid while negotiating. */
  raiseFare(input: RaiseFareInput): Promise<RideSnapshot>;
  /** Customer turns exact-price auto-accept on or off while negotiating. */
  setAutoAccept(input: SetAutoAcceptInput): Promise<RideSnapshot>;
  /** Customer declines one driver's offer. */
  declineOffer(input: DeclineOfferInput): Promise<RideSnapshot>;
  /** Customer edits stops while negotiating (live offers die, new round). */
  updateStops(input: UpdateStopsInput): Promise<RideSnapshot>;
  /** Assigned driver arrives at / leaves an intermediate stop (IN_TRIP, in order). */
  arriveStop(input: StopEventInput): Promise<RideSnapshot>;
  departStop(input: StopEventInput): Promise<RideSnapshot>;
  /** Driver withdraws their pending offer. */
  withdrawOffer(input: WithdrawOfferInput): Promise<RideSnapshot>;
  /** Assigned driver gives up before the trip; the ride returns to bidding. */
  driverCancel(input: DriverCancelInput): Promise<RideSnapshot>;
  /** Customer no-show after the wait; may record a NO_SHOW fee. */
  markNoShow(input: NoShowInput): Promise<RideSnapshot>;
  /** Worker returns stuck ASSIGNED / EN_ROUTE rides to bidding. */
  timeoutDue(input: {
    now: Date;
    policy: RideTimeoutPolicy;
    windowExpiresAt: Date;
    limit?: number;
  }): Promise<string[]>;
  /** Unpaid late-cancel / no-show fees of a customer. */
  pendingFeeTotal(customerId: string): Promise<number>;
}

export class MemoryRideRepository implements RideRepository {
  private readonly ledger = new RideLedger();
  private tail: Promise<void> = Promise.resolve();

  constructor(private readonly vouchers?: VoucherRedeemer) {}

  create(input: CreateRideInput, withinCreate?: RideCreateHook): Promise<RideSnapshot> {
    return this.run(async () => {
      const ride = finish(this.ledger.create(input));
      if (withinCreate) {
        try {
          await withinCreate({ tx: undefined, rideId: ride.id });
        } catch (error) {
          this.ledger.discardNew(ride.id); // same all-or-nothing as the Prisma transaction
          throw error;
        }
      }
      return ride;
    });
  }

  findById(id: string, now: Date): Promise<RideSnapshot | null> {
    return this.run(() => this.ledger.read(id, now));
  }

  private readonly routeKm = new Map<string, number>();

  async setRouteDistanceKm(rideId: string, km: number): Promise<void> {
    this.routeKm.set(rideId, km);
  }

  async routeDistanceKm(rideId: string): Promise<number | null> {
    return this.routeKm.get(rideId) ?? null;
  }

  async listOpen(
    now: Date,
    limit?: number,
    vehicleClassCode?: string,
    area?: GeoBox,
  ): Promise<OpenRideListing[]> {
    const rows = await this.run(() => this.ledger.listOpen(now, limit, vehicleClassCode, area));
    return rows.map((row) => ({ ...row, routeDistanceKm: this.routeKm.get(row.id) ?? null }));
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

  listIdsForDriverInStatuses(driverId: string, statuses: readonly string[]): Promise<string[]> {
    return this.run(() => this.ledger.listIdsForDriverInStatuses(driverId, statuses));
  }

  listIdsForCustomerInStatuses(customerId: string, statuses: readonly string[]): Promise<string[]> {
    return this.run(() => this.ledger.listIdsForCustomerInStatuses(customerId, statuses));
  }

  customerCancelTimes(customerId: string, since: Date): Promise<Date[]> {
    return this.run(() => this.ledger.customerCancelTimes(customerId, since));
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
    return this.run(() => {
      const ride = finish(this.ledger.complete(input));
      // Earlier unpaid customer fees are collected in this ride's cash.
      const charges = this.ledger.pendingFees(ride.customerId).filter((fee) => fee.rideId !== ride.id);
      if (charges.length === 0) {
        return ride;
      }
      this.ledger.collectFees(ride.id, charges, input.now);
      const reread = this.ledger.read(ride.id, input.now) ?? ride;
      return {
        ...reread,
        collectedFees: charges.map((fee) => ({
          id: fee.id,
          amountVnd: fee.amountVnd,
          beneficiaryDriverId: fee.beneficiaryDriverId,
        })),
      };
    }).then(async (ride) => {
      await onCompleted?.(null, ride);
      return ride;
    });
  }

  raiseFare(input: RaiseFareInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.raiseFare(input)));
  }

  setAutoAccept(input: SetAutoAcceptInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.setAutoAccept(input)));
  }

  declineOffer(input: DeclineOfferInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.declineOffer(input)));
  }

  updateStops(input: UpdateStopsInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.updateStops(input)));
  }

  arriveStop(input: StopEventInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.arriveStop(input)));
  }

  departStop(input: StopEventInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.departStop(input)));
  }

  withdrawOffer(input: WithdrawOfferInput): Promise<RideSnapshot> {
    return this.run(() => finish(this.ledger.withdrawOffer(input)));
  }

  driverCancel(input: DriverCancelInput): Promise<RideSnapshot> {
    return this.run(async () => {
      const ride = finish(this.ledger.driverCancel(input));
      await this.vouchers?.release({ entityType: 'RIDE', entityId: ride.id });
      return ride;
    });
  }

  markNoShow(input: NoShowInput): Promise<RideSnapshot> {
    return this.run(async () => {
      const ride = finish(this.ledger.markNoShow(input));
      await this.vouchers?.release({ entityType: 'RIDE', entityId: ride.id });
      return ride;
    });
  }

  timeoutDue(input: {
    now: Date;
    policy: RideTimeoutPolicy;
    windowExpiresAt: Date;
    limit?: number;
  }): Promise<string[]> {
    return this.run(async () => {
      const ids = this.ledger.listTimeoutCandidates(input.now, input.policy);
      const picked = input.limit && input.limit > 0 ? ids.slice(0, input.limit) : ids;
      const done: string[] = [];
      for (const id of picked) {
        const outcome = this.ledger.systemTimeout({
          rideId: id,
          now: input.now,
          policy: input.policy,
          windowExpiresAt: input.windowExpiresAt,
        });
        if (outcome.ride) {
          await this.vouchers?.release({ entityType: 'RIDE', entityId: id });
          done.push(id);
        }
      }
      return done;
    });
  }

  pendingFeeTotal(customerId: string): Promise<number> {
    return this.run(() =>
      this.ledger.pendingFees(customerId).reduce((sum, fee) => sum + fee.amountVnd, 0),
    );
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
