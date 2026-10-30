import { lockDriverAssignment } from '../../shared/tx/driver-assignment-lock.js';
import type { GeoBox } from '../dispatch/dispatch-filter.js';
import { cancellationCountsAgainstDriver } from '../../shared/cancel-actor.js';
import type { DriverJobCounts } from '../../shared/driver-job-counts.js';
import { randomUUID } from 'node:crypto';
import {
  normalizeRegionFilter,
  regionCodeOrLabelFallbackWhere,
  resolveServiceRegionCode,
} from '../service-area/service-regions.js';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import {
  writeOpsActionOutbox,
  writeRideUnassignedOutbox,
  writeStatusOutbox,
} from '../communication/outbox/outbox.write.js';
import { RideRuleError } from './ride.error.js';
import {
  redeemVoucherInTx,
  releaseVoucherInTx,
  VoucherRejectedError,
} from '../promotion/promotion-redemption.js';
import type { CompletionHook } from '../../shared/tx/completion-hook.js';
import {
  RideLedger,
  rideRowFromRecord,
  type CancelInput,
  type CreateRideInput,
  DRIVER_HISTORY_RIDE_STATUSES,
  type DriverHistoryWindow,
  type DriverLifecycleInput,
  type OfferInput,
  type OpenRideListing,
  type OpsCancelInput,
  type OpsReassignInput,
  type RideSnapshot,
  type CancelActorName,
  type CustomerFeeRecord,
  type DeclineOfferInput,
  type DriverCancelInput,
  type NoShowInput,
  type RaiseFareInput,
  type RideOfferStatusName,
  type RideStatusName,
  type RideTimeoutPolicy,
  type SelectInput,
  type StopEventInput,
  type UpdateStopsInput,
  type WithdrawOfferInput,
} from './ride-ledger.js';
import type { OpsInterveneResult, OpsRidePage, RideCreateHook, RideRepository } from './ride.repository.js';

type RideTx = Prisma.TransactionClient;
export { lockDriverAssignment };

class RideAssignmentConflict extends Error {
  constructor() {
    super('Ride assignment conflict');
    this.name = 'RideAssignmentConflict';
  }
}

export class PrismaRideRepository implements RideRepository {
  constructor(private readonly db: PrismaClient) {}

  async create(input: CreateRideInput, withinCreate?: RideCreateHook): Promise<RideSnapshot> {
    let outcome: Awaited<ReturnType<RideLedger['create']>>;
    try {
      outcome = await this.db.$transaction(async (tx) => {
        const ledger = await this.hydrateCustomer(tx, input.customerId, input.idempotencyKey);
        const created = ledger.create(input);
        await this.persist(tx, ledger);
        // DEC-PROD-071: parcel row commits with the ride (no window without it).
        if (withinCreate && created.ride) await withinCreate({ tx, rideId: created.ride.id });
        return created;
      });
    } catch (error) {
      if (!isUniqueConflict(error)) {
        throw error;
      }
      const existing = await this.findByCustomerKey(
        input.customerId,
        input.idempotencyKey,
        input.now,
      );
      if (existing) {
        return existing;
      }
      throw new RideRuleError('RIDE_ALREADY_OPEN');
    }
    if (outcome.error || !outcome.ride) {
      throw new RideRuleError(outcome.error ?? 'RIDE_NOT_FOUND');
    }
    return outcome.ride;
  }

  async findById(id: string, now: Date, attempt = 0): Promise<RideSnapshot | null> {
    const result = await this.db.$transaction(async (tx) => {
      const ledger = await this.hydrateRide(tx, id);
      if (!ledger) {
        return { ride: null, stale: false };
      }
      const ride = ledger.read(id, now);
      const stale = await this.persist(tx, ledger);
      return { ride, stale };
    });
    if (result.stale && attempt < 1) {
      return this.findById(id, now, attempt + 1);
    }
    return result.ride;
  }

  async listOpen(
    now: Date,
    limit?: number,
    vehicleClassCode?: string,
    area?: GeoBox,
  ): Promise<OpenRideListing[]> {
    const take =
      limit !== undefined && Number.isSafeInteger(limit) && limit > 0 ? limit : undefined;
    const rides = await this.db.ride.findMany({
      where: {
        status: 'NEGOTIATING',
        expiresAt: { gt: now },
        ...(vehicleClassCode ? { vehicleClassCode } : {}),
        ...(area
          ? {
              pickupLat: { gte: area.minLat, lte: area.maxLat },
              pickupLng: { gte: area.minLng, lte: area.maxLng },
            }
          : {}),
      },
      orderBy: [{ expiresAt: 'asc' }, { id: 'asc' }],
      ...(take !== undefined ? { take } : {}),
      select: {
        id: true,
        customerId: true,
        pickupLat: true,
        pickupLng: true,
        pickupLabel: true,
        dropoffLat: true,
        dropoffLng: true,
        dropoffLabel: true,
        offeredFareVnd: true,
        referenceFareVnd: true,
        vehicleClassCode: true,
        expiresAt: true,
        routeVersion: true,
        stops: { orderBy: { seq: 'asc' }, select: { lat: true, lng: true, label: true } },
        _count: { select: { offers: true } },
      },
    });
    return rides.map((ride) => ({
      id: ride.id,
      customerId: ride.customerId,
      status: 'NEGOTIATING',
      pickup: { lat: ride.pickupLat, lng: ride.pickupLng, label: ride.pickupLabel },
      dropoff: { lat: ride.dropoffLat, lng: ride.dropoffLng, label: ride.dropoffLabel },
      offeredFareVnd: ride.offeredFareVnd,
      referenceFareVnd: ride.referenceFareVnd,
      vehicleClassCode: ride.vehicleClassCode,
      expiresAt: ride.expiresAt,
      offerCount: ride._count.offers,
      stops: ride.stops,
      routeVersion: ride.routeVersion,
    }));
  }

  async offer(input: OfferInput): Promise<RideSnapshot> {
    const outcome = await this.db.$transaction(async (tx) => {
      const ledger = await this.hydrateRide(tx, input.rideId);
      if (!ledger) {
        return { error: 'RIDE_NOT_FOUND' as const };
      }
      const offered = ledger.offer(input);
      await this.persist(tx, ledger);
      return offered;
    });
    if (outcome.error || !outcome.ride) {
      throw new RideRuleError(outcome.error ?? 'RIDE_NOT_FOUND');
    }
    return outcome.ride;
  }

  async select(input: SelectInput): Promise<RideSnapshot> {
    let outcome: Awaited<ReturnType<RideLedger['select']>>;
    try {
      outcome = await this.db.$transaction(async (tx) => {
        const priorSelection = await tx.rideSelection.findUnique({
          where: {
            customerId_idempotencyKey: {
              customerId: input.customerId,
              idempotencyKey: input.idempotencyKey,
            },
          },
        });
        const ledger = await this.hydrateSelection(
          tx,
          input.rideId,
          input.customerId,
          input.idempotencyKey,
        );

        if (!priorSelection) {
          const offer = await tx.rideOffer.findUnique({
            where: { id: input.offerId },
            select: { id: true, rideId: true, driverId: true, status: true },
          });
          if (offer && offer.rideId === input.rideId && offer.status === 'PENDING') {
            // Serialize every assignment of this driver (ride select + food claim) so
            // two customers cannot both pass the capacity count at the same time.
            await lockDriverAssignment(tx, offer.driverId);
            const maxJobs = input.maxConcurrentJobs ?? 1;
            const [activeRides, activeFood] = await Promise.all([
              tx.ride.count({
                where: {
                  assignedDriverId: offer.driverId,
                  status: {
                    in: ['ASSIGNED', 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED', 'IN_TRIP'],
                  },
                },
              }),
              tx.foodOrder.count({
                where: {
                  assignedDriverId: offer.driverId,
                  // PREPARING counts once a driver was assigned early (food early assign).
                  status: { in: ['PREPARING', 'ASSIGNED', 'PICKED_UP'] },
                },
              }),
            ]);
            if (activeRides + activeFood >= maxJobs) {
              throw new RideRuleError('DRIVER_AT_CAPACITY');
            }
          }
        }

        let selected = ledger.select(input);
        // DEC-PROD-024: the voucher is reserved in the selection transaction, on the agreed
        // fare; a rejection rolls the selection back. Replays (prior selection) never redeem.
        const voucherCode = input.voucherCode?.trim();
        if (!priorSelection && voucherCode && selected.ride && !selected.error) {
          const agreed = selected.ride.agreedFareVnd ?? 0;
          const redeemed = await redeemVoucherInTx(
            tx,
            {
              code: voucherCode,
              userId: input.customerId,
              entityType: 'RIDE',
              entityId: selected.ride.id,
              serviceType: 'RIDE',
              orderAmount: agreed,
            },
            input.now,
          );
          const applied = ledger.applyVoucher(selected.ride.id, {
            code: redeemed.code,
            discountVnd: redeemed.discountVnd,
            sponsor: redeemed.sponsor,
          });
          if (applied) {
            selected = { ride: applied };
          }
        }
        await this.persist(tx, ledger);
        return selected;
      });
    } catch (error) {
      const conflict = error instanceof RideAssignmentConflict || isUniqueConflict(error);
      const rule = error instanceof RideRuleError || error instanceof VoucherRejectedError;
      if (!conflict && !rule) {
        throw error;
      }
      // Idempotency wins: a same-key request that committed while this one waited (on the ride
      // row or the voucher row) makes this rule error a replay.
      const replay = await this.selectionReplay(input);
      if (replay) {
        return replay;
      }
      if (rule) {
        throw error;
      }
      throw new RideRuleError('RIDE_OFFER_UNAVAILABLE');
    }
    if (outcome.error || !outcome.ride) {
      const replay = outcome.error ? await this.selectionReplay(input) : null;
      if (replay) {
        return replay;
      }
      throw new RideRuleError(outcome.error ?? 'RIDE_NOT_FOUND');
    }
    return outcome.ride;
  }

  private async selectionReplay(input: SelectInput): Promise<RideSnapshot | null> {
    const prior = await this.db.rideSelection.findUnique({
      where: {
        customerId_idempotencyKey: {
          customerId: input.customerId,
          idempotencyKey: input.idempotencyKey,
        },
      },
    });
    if (!prior) {
      return null;
    }
    const ride = await this.findById(prior.rideId, input.now);
    return ride && ride.customerId === input.customerId ? ride : null;
  }

  async cancel(input: CancelInput): Promise<RideSnapshot> {
    let outcome: Awaited<ReturnType<RideLedger['cancel']>>;
    try {
      outcome = await this.db.$transaction(async (tx) => {
        const ledger = await this.hydrateRide(tx, input.rideId);
        if (!ledger) {
          return { error: 'RIDE_NOT_FOUND' as const };
        }
        const cancelled = ledger.cancel(input);
        await this.persist(tx, ledger);
        if (cancelled.ride && !cancelled.error) {
          // Idempotent: a ride without a voucher has nothing to release.
          await releaseVoucherInTx(tx, { entityType: 'RIDE', entityId: input.rideId }, input.now);
        }
        return cancelled;
      });
    } catch (error) {
      if (error instanceof RideAssignmentConflict) {
        throw new RideRuleError('RIDE_STATUS_CONFLICT');
      }
      throw error;
    }
    if (outcome.error || !outcome.ride) {
      throw new RideRuleError(outcome.error ?? 'RIDE_NOT_FOUND');
    }
    return outcome.ride;
  }

  async opsCancel(
    input: OpsCancelInput,
    actorUserId: string,
    reason: string,
  ): Promise<OpsInterveneResult> {
    return this.opsIntervene(input.rideId, input.now, actorUserId, reason, 'CANCEL', (ledger) =>
      ledger.opsCancel(input),
    );
  }

  async opsReassign(
    input: OpsReassignInput,
    actorUserId: string,
    reason: string,
  ): Promise<OpsInterveneResult> {
    return this.opsIntervene(input.rideId, input.now, actorUserId, reason, 'REASSIGN', (ledger) =>
      ledger.opsReassign(input),
    );
  }

  raiseFare(input: RaiseFareInput): Promise<RideSnapshot> {
    return this.mutate(input.rideId, (ledger) => ledger.raiseFare(input));
  }

  declineOffer(input: DeclineOfferInput): Promise<RideSnapshot> {
    return this.mutate(input.rideId, (ledger) => ledger.declineOffer(input));
  }

  withdrawOffer(input: WithdrawOfferInput): Promise<RideSnapshot> {
    return this.mutate(input.rideId, (ledger) => ledger.withdrawOffer(input));
  }

  updateStops(input: UpdateStopsInput): Promise<RideSnapshot> {
    return this.mutate(input.rideId, (ledger) => ledger.updateStops(input));
  }

  arriveStop(input: StopEventInput): Promise<RideSnapshot> {
    return this.driverLifecycle(
      input,
      (ledger) => ledger.arriveStop(input),
      (tx, ride) => this.stopOutbox(tx as RideTx, ride.id, input.seq, 'ARRIVED'),
    );
  }

  departStop(input: StopEventInput): Promise<RideSnapshot> {
    return this.driverLifecycle(
      input,
      (ledger) => ledger.departStop(input),
      (tx, ride) => this.stopOutbox(tx as RideTx, ride.id, input.seq, 'DEPARTED'),
    );
  }

  driverCancel(input: DriverCancelInput): Promise<RideSnapshot> {
    return this.mutate(input.rideId, (ledger) => ledger.driverCancel(input), {
      releaseVoucherAt: input.now,
    });
  }

  markNoShow(input: NoShowInput): Promise<RideSnapshot> {
    return this.mutate(input.rideId, (ledger) => ledger.markNoShow(input), {
      releaseVoucherAt: input.now,
    });
  }

  /** Return rides stuck in ASSIGNED / DRIVER_EN_ROUTE to bidding (worker). */
  async timeoutDue(input: {
    now: Date;
    policy: RideTimeoutPolicy;
    windowExpiresAt: Date;
    limit?: number;
  }): Promise<string[]> {
    const { now, policy } = input;
    const or: Prisma.RideWhereInput[] = [];
    if (policy.assignedTimeoutMinutes > 0) {
      or.push({
        status: 'ASSIGNED',
        statusChangedAt: { lte: new Date(now.getTime() - policy.assignedTimeoutMinutes * 60_000) },
      });
    }
    if (policy.enRouteTimeoutMinutes > 0) {
      or.push({
        status: 'DRIVER_EN_ROUTE',
        statusChangedAt: { lte: new Date(now.getTime() - policy.enRouteTimeoutMinutes * 60_000) },
      });
    }
    if (or.length === 0) {
      return [];
    }
    const due = await this.db.ride.findMany({
      where: { OR: or },
      orderBy: [{ statusChangedAt: 'asc' }, { id: 'asc' }],
      take: Math.min(Math.max(input.limit ?? 100, 1), 500),
      select: { id: true },
    });
    const done: string[] = [];
    for (const row of due) {
      try {
        await this.mutate(
          row.id,
          (ledger) =>
            ledger.systemTimeout({
              rideId: row.id,
              now,
              policy,
              windowExpiresAt: input.windowExpiresAt,
            }),
          { releaseVoucherAt: now },
        );
        done.push(row.id);
      } catch (error) {
        if (!(error instanceof RideRuleError)) {
          throw error;
        }
      }
    }
    return done;
  }

  async pendingFeeTotal(customerId: string): Promise<number> {
    const sum = await this.db.customerFeeCharge.aggregate({
      where: { customerId, status: 'PENDING' },
      _sum: { amountVnd: true },
    });
    return sum._sum.amountVnd ?? 0;
  }

  private async mutate(
    rideId: string,
    apply: (ledger: RideLedger) => Awaited<ReturnType<RideLedger['cancel']>>,
    options: { releaseVoucherAt?: Date } = {},
  ): Promise<RideSnapshot> {
    let outcome: Awaited<ReturnType<RideLedger['cancel']>>;
    try {
      outcome = await this.db.$transaction(async (tx) => {
        const ledger = await this.hydrateRide(tx, rideId);
        if (!ledger) {
          return { error: 'RIDE_NOT_FOUND' as const };
        }
        const next = apply(ledger);
        if (next.error || !next.ride) {
          await this.persist(tx, ledger);
          return next;
        }
        await this.persist(tx, ledger);
        if (options.releaseVoucherAt) {
          await releaseVoucherInTx(tx, { entityType: 'RIDE', entityId: rideId }, options.releaseVoucherAt);
        }
        return next;
      });
    } catch (error) {
      if (error instanceof RideAssignmentConflict) {
        throw new RideRuleError('RIDE_STATUS_CONFLICT');
      }
      throw error;
    }
    if (outcome.error || !outcome.ride) {
      throw new RideRuleError(outcome.error ?? 'RIDE_NOT_FOUND');
    }
    return outcome.ride;
  }

  async listPage(
    page: number,
    limit: number,
    now: Date,
    filter?: { status?: string; q?: string; zone?: string; serviceType?: string },
  ): Promise<OpsRidePage> {
    // serviceType is not a Ride column; intentionally ignored (no fake filter).
    const where: any = {};
    if (filter?.status && filter.status !== 'ALL') {
      where.status = filter.status.toUpperCase();
    }
    if (filter?.zone && filter.zone !== 'ALL') {
      const code = normalizeRegionFilter(filter.zone);
      if (code) {
        where.AND = where.AND || [];
        where.AND.push(
          regionCodeOrLabelFallbackWhere(code, ['pickupLabel', 'dropoffLabel']),
        );
      }
    }
    if (filter?.q && filter.q.trim()) {
      const q = filter.q.trim();
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(q);
      const orConditions: any[] = [
        { pickupLabel: { contains: q, mode: 'insensitive' } },
        { dropoffLabel: { contains: q, mode: 'insensitive' } },
        { customer: { displayName: { contains: q, mode: 'insensitive' } } },
        { customer: { phone: { contains: q, mode: 'insensitive' } } },
      ];
      if (isUuid) {
        orConditions.push(
          { id: q },
          { customerId: q },
          { assignedDriverId: q },
        );
      }
      where.OR = orConditions;
    }
    const [total, rows] = await Promise.all([
      this.db.ride.count({ where }),
      this.db.ride.findMany({
        where,
        include: { offers: true, stops: { orderBy: { seq: 'asc' } } },
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    const ledger = this.ledgerFrom(rows, []);
    const items: RideSnapshot[] = [];
    for (const row of rows) {
      const ride = ledger.read(row.id, now);
      if (ride) {
        items.push(ride);
      }
    }
    // Ops list is read-mostly: apply expire-on-read for display only.
    // Persisting here would mass-write EXPIRED while operators browse.
    return { items, total };
  }

  async listForCustomer(
    customerId: string,
    page: number,
    limit: number,
    now: Date,
  ): Promise<OpsRidePage> {
    const where = { customerId };
    const [total, rows] = await Promise.all([
      this.db.ride.count({ where }),
      this.db.ride.findMany({
        where,
        include: { offers: true, stops: { orderBy: { seq: 'asc' } } },
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    const ledger = this.ledgerFrom(rows, []);
    const items: RideSnapshot[] = [];
    for (const row of rows) {
      const ride = ledger.read(row.id, now);
      if (ride) {
        items.push(ride);
      }
    }
    await this.db.$transaction(async (tx) => {
      await this.persist(tx, ledger);
    });
    return { items, total };
  }

  async countFinishedForDrivers(
    driverIds: readonly string[],
  ): Promise<Map<string, DriverJobCounts>> {
    const counts = new Map<string, DriverJobCounts>();
    if (driverIds.length === 0) {
      return counts;
    }
    const rows = await this.db.ride.groupBy({
      by: ['assignedDriverId', 'status', 'cancelledBy'],
      where: {
        assignedDriverId: { in: [...driverIds] },
        status: { in: [...DRIVER_HISTORY_RIDE_STATUSES] },
      },
      _count: { _all: true },
    });
    for (const row of rows) {
      if (!row.assignedDriverId) continue;
      // DEC-PROD-035: only driver cancellations count against the driver.
      if (!cancellationCountsAgainstDriver(row.status, row.cancelledBy)) continue;
      const current = counts.get(row.assignedDriverId) ?? { completed: 0, finished: 0 };
      current.finished += row._count._all;
      if (row.status === 'COMPLETED') {
        current.completed += row._count._all;
      }
      counts.set(row.assignedDriverId, current);
    }
    // Rides the driver dropped after assignment (self-cancel / timeout) count as finished.
    const dropped = await this.db.driverJobCancellation.groupBy({
      by: ['driverId'],
      where: { driverId: { in: [...driverIds] }, entityType: 'RIDE', actor: { in: ['DRIVER', 'SYSTEM'] } },
      _count: { _all: true },
    });
    for (const row of dropped) {
      const current = counts.get(row.driverId) ?? { completed: 0, finished: 0 };
      current.finished += row._count._all;
      counts.set(row.driverId, current);
    }
    return counts;
  }

  async listIdsForDriverInStatuses(driverId: string, statuses: readonly string[]): Promise<string[]> {
    const rows = await this.db.ride.findMany({
      where: { assignedDriverId: driverId, status: { in: [...statuses] as never } },
      select: { id: true },
    });
    return rows.map((row) => row.id);
  }

  async customerCancelTimes(customerId: string, since: Date): Promise<Date[]> {
    const rows = await this.db.ride.findMany({
      where: {
        customerId,
        status: 'CANCELLED',
        cancelledBy: 'CUSTOMER',
        assignedDriverId: { not: null },
        statusChangedAt: { gte: since },
      },
      select: { statusChangedAt: true },
      orderBy: { statusChangedAt: 'desc' },
      take: 50,
    });
    return rows.flatMap((row) => (row.statusChangedAt ? [row.statusChangedAt] : []));
  }

  async listIdsForCustomerInStatuses(customerId: string, statuses: readonly string[]): Promise<string[]> {
    const rows = await this.db.ride.findMany({
      where: { customerId, status: { in: [...statuses] as never } },
      orderBy: { createdAt: 'desc' },
      take: 5,
      select: { id: true },
    });
    return rows.map((row) => row.id);
  }

  async listFinishedForDriver(
    driverId: string,
    window: DriverHistoryWindow,
  ): Promise<RideSnapshot[]> {
    const rows = await this.db.ride.findMany({
      where: {
        assignedDriverId: driverId,
        status: { in: [...DRIVER_HISTORY_RIDE_STATUSES] },
        updatedAt: {
          ...(window.before ? { lte: window.before } : {}),
          ...(window.since ? { gte: window.since } : {}),
        },
      },
      include: { offers: true, stops: { orderBy: { seq: 'asc' } } },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take: window.limit,
    });
    // Terminal rides never expire, so reading them needs no persist pass.
    const ledger = this.ledgerFrom(rows, []);
    const now = new Date();
    return rows.flatMap((row) => {
      const ride = ledger.read(row.id, now);
      return ride ? [ride] : [];
    });
  }

  private async opsIntervene(
    rideId: string,
    now: Date,
    actorUserId: string,
    reason: string,
    action: 'CANCEL' | 'REASSIGN',
    apply: (ledger: RideLedger) => Awaited<ReturnType<RideLedger['opsCancel']>>,
  ): Promise<OpsInterveneResult> {
    let result: { ride?: RideSnapshot; error?: RideRuleError['code']; auditId?: string };
    try {
      result = await this.db.$transaction(async (tx) => {
        const ledger = await this.hydrateRide(tx, rideId);
        if (!ledger) {
          return { error: 'RIDE_NOT_FOUND' as const };
        }
        const outcome = apply(ledger);
        if (outcome.error || !outcome.ride) {
          return { error: outcome.error ?? 'RIDE_NOT_FOUND' };
        }
        await this.persist(tx, ledger);
        // Cancel and reassign both return the reserved voucher (reassign clears the snapshot).
        await releaseVoucherInTx(tx, { entityType: 'RIDE', entityId: rideId }, now);
        const auditId = randomUUID();
        await tx.opsAuditLog.create({
          data: {
            id: auditId,
            actorUserId,
            action,
            entityType: 'RIDE',
            entityId: rideId,
            reason,
            metadata: { status: outcome.ride.status },
          },
        });
        await writeOpsActionOutbox(tx, {
          aggregateType: 'Ride',
          aggregateId: rideId,
          action: action === 'CANCEL' ? 'cancel' : 'reassign',
          auditId,
          status: outcome.ride.status,
          payload: { reason },
        });
        if (action === 'CANCEL') {
          await writeStatusOutbox(tx, {
            aggregateType: 'Ride',
            aggregateId: rideId,
            status: 'CANCELLED',
            payload: { reason, auditId },
          });
        }
        return { ride: outcome.ride, auditId };
      });
    } catch (error) {
      if (error instanceof RideAssignmentConflict) {
        throw new RideRuleError('RIDE_STATUS_CONFLICT');
      }
      throw error;
    }
    if (result.error || !result.ride || !result.auditId) {
      throw new RideRuleError(result.error ?? 'RIDE_NOT_FOUND');
    }
    return { ride: result.ride, auditId: result.auditId };
  }

  markEnRoute(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.driverLifecycle(input, (ledger) => ledger.markEnRoute(input));
  }

  markArrived(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.driverLifecycle(input, (ledger) => ledger.markArrived(input));
  }

  startTrip(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.driverLifecycle(input, (ledger) => ledger.startTrip(input));
  }

  complete(
    input: DriverLifecycleInput,
    onCompleted?: CompletionHook<RideSnapshot>,
  ): Promise<RideSnapshot> {
    return this.driverLifecycle(input, (ledger) => ledger.complete(input), onCompleted, true);
  }

  async expireDue(now: Date, limit = 100): Promise<string[]> {
    const take =
      Number.isSafeInteger(limit) && limit > 0 ? Math.min(limit, 500) : 100;
    const due = await this.db.ride.findMany({
      where: { status: 'NEGOTIATING', expiresAt: { lte: now } },
      orderBy: [{ expiresAt: 'asc' }, { id: 'asc' }],
      take,
      select: { id: true },
    });
    const expired: string[] = [];
    for (const row of due) {
      const ok = await this.db.$transaction(async (tx) => {
        const updated = await tx.ride.updateMany({
          where: { id: row.id, status: 'NEGOTIATING', expiresAt: { lte: now } },
          data: { status: 'EXPIRED' },
        });
        if (updated.count !== 1) {
          return false;
        }
        await tx.ride.update({ where: { id: row.id }, data: { statusChangedAt: now } });
        // Live offers die with the ride.
        await tx.rideOffer.updateMany({
          where: { rideId: row.id, status: 'PENDING' },
          data: { status: 'LOST' },
        });
        await writeStatusOutbox(tx, {
          aggregateType: 'Ride',
          aggregateId: row.id,
          status: 'EXPIRED',
        });
        return true;
      });
      if (ok) {
        expired.push(row.id);
      }
    }
    return expired;
  }

  /**
   * Realtime hint for a stop event: an IN_TRIP snapshot with its own key (deduped on repeats)
   * so the customer / driver apps re-GET the ride. `stopEvent` keeps the relay from re-sending
   * the "trip started" push.
   */
  private async stopOutbox(
    tx: Prisma.TransactionClient,
    rideId: string,
    seq: number,
    event: 'ARRIVED' | 'DEPARTED',
  ): Promise<void> {
    await writeStatusOutbox(tx, {
      aggregateType: 'Ride',
      aggregateId: rideId,
      status: 'IN_TRIP',
      eventKeySuffix: `stop-${seq}-${event.toLowerCase()}`,
      payload: { stopEvent: event, stopSeq: seq },
    });
  }

  private async driverLifecycle(
    input: DriverLifecycleInput,
    apply: (ledger: RideLedger) => Awaited<ReturnType<RideLedger['markEnRoute']>>,
    onChanged?: CompletionHook<RideSnapshot>,
    collectFees = false,
  ): Promise<RideSnapshot> {
    let outcome: Awaited<ReturnType<RideLedger['markEnRoute']>>;
    try {
      outcome = await this.db.$transaction(async (tx) => {
        const ledger = await this.hydrateRide(tx, input.rideId);
        if (!ledger) {
          return { error: 'RIDE_NOT_FOUND' as const };
        }
        let next = apply(ledger);
        let collected: CustomerFeeRecord[] = [];
        if (collectFees && next.ride && !next.error) {
          // Earlier late-cancel / no-show fees are collected in this ride's cash.
          collected = await this.lockPendingFees(tx, next.ride.customerId, next.ride.id);
          if (collected.length > 0) {
            ledger.collectFees(next.ride.id, collected, input.now);
            const reread = ledger.read(next.ride.id, input.now);
            if (reread) {
              next = {
                ride: {
                  ...reread,
                  collectedFees: collected.map((fee) => ({
                    id: fee.id,
                    amountVnd: fee.amountVnd,
                    beneficiaryDriverId: fee.beneficiaryDriverId,
                  })),
                },
              };
            }
          }
        }
        await this.persist(tx, ledger);
        if (collected.length > 0) {
          await tx.customerFeeCharge.updateMany({
            where: { id: { in: collected.map((fee) => fee.id) }, status: 'PENDING' },
            data: { status: 'COLLECTED', collectedRideId: input.rideId, collectedAt: input.now },
          });
        }
        if (next.ride && !next.error && onChanged) {
          await onChanged(tx, next.ride);
        }
        return next;
      });
    } catch (error) {
      if (error instanceof RideAssignmentConflict) {
        throw new RideRuleError('RIDE_STATUS_CONFLICT');
      }
      throw error;
    }
    if (outcome.error || !outcome.ride) {
      throw new RideRuleError(outcome.error ?? 'RIDE_NOT_FOUND');
    }
    return outcome.ride;
  }

  private async lockPendingFees(
    tx: RideTx,
    customerId: string,
    rideId: string,
  ): Promise<CustomerFeeRecord[]> {
    await tx.$queryRaw`
      SELECT id FROM "customer_fee_charges"
      WHERE "customerId" = CAST(${customerId} AS uuid) AND "status" = 'PENDING'
      ORDER BY id
      FOR UPDATE
    `;
    const rows = await tx.customerFeeCharge.findMany({
      where: { customerId, status: 'PENDING', rideId: { not: rideId } },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    });
    return rows.map((row) => ({
      id: row.id,
      customerId: row.customerId,
      rideId: row.rideId,
      kind: row.kind,
      amountVnd: row.amountVnd,
      beneficiaryDriverId: row.beneficiaryDriverId,
      status: row.status,
      collectedRideId: row.collectedRideId,
      createdAt: row.createdAt,
    }));
  }

  private async findByCustomerKey(
    customerId: string,
    idempotencyKey: string,
    now: Date,
  ): Promise<RideSnapshot | null> {
    const ride = await this.db.ride.findUnique({
      where: { customerId_idempotencyKey: { customerId, idempotencyKey } },
    });
    if (!ride) {
      return null;
    }
    return this.findById(ride.id, now);
  }

  private async hydrateCustomer(
    tx: RideTx,
    customerId: string,
    idempotencyKey: string,
  ): Promise<RideLedger> {
    await tx.$queryRaw`
      SELECT id FROM "rides"
      WHERE "customerId" = CAST(${customerId} AS uuid)
        AND ("idempotencyKey" = ${idempotencyKey} OR "status" = 'NEGOTIATING')
      ORDER BY id
      FOR UPDATE
    `;
    const rides = await tx.ride.findMany({
      where: {
        customerId,
        OR: [{ idempotencyKey }, { status: 'NEGOTIATING' }],
      },
      include: { offers: true, stops: { orderBy: { seq: 'asc' } } },
    });
    return this.ledgerFrom(rides, []);
  }

  private async hydrateRide(tx: RideTx, rideId: string): Promise<RideLedger | null> {
    await this.lockRides(tx, [rideId]);
    const ride = await tx.ride.findUnique({ where: { id: rideId }, include: { offers: true, stops: { orderBy: { seq: 'asc' } } } });
    if (!ride) {
      return null;
    }
    await this.lockOffers(tx, rideId);
    return this.ledgerFrom([ride], []);
  }

  private async hydrateSelection(
    tx: RideTx,
    rideId: string,
    customerId: string,
    idempotencyKey: string,
  ): Promise<RideLedger> {
    await tx.$queryRaw`
      SELECT id FROM "ride_selections"
      WHERE "customerId" = CAST(${customerId} AS uuid)
        AND "idempotencyKey" = ${idempotencyKey}
      FOR UPDATE
    `;
    const selection = await tx.rideSelection.findUnique({
      where: { customerId_idempotencyKey: { customerId, idempotencyKey } },
    });
    const ids = [rideId];
    if (selection && selection.rideId !== rideId) {
      ids.push(selection.rideId);
    }
    await this.lockRides(tx, ids);
    for (const id of ids) {
      await this.lockOffers(tx, id);
    }
    const rides = await tx.ride.findMany({
      where: { id: { in: ids } },
      include: { offers: true, stops: { orderBy: { seq: 'asc' } } },
    });
    return this.ledgerFrom(rides, selection ? [selection] : []);
  }

  private ledgerFrom(
    rides: Array<{
      stops?: Array<{
        seq: number;
        lat: number;
        lng: number;
        label: string;
        arrivedAt: Date | null;
        departedAt: Date | null;
      }>;
      routeVersion?: number;
      stopFeeVnd?: number;
      stopWaitFreeMinutes?: number;
      stopWaitFeeVndPerMinute?: number;
      waitFeeVnd?: number;
      id: string;
      customerId: string;
      pickupLat: number;
      pickupLng: number;
      pickupLabel: string;
      dropoffLat: number;
      dropoffLng: number;
      dropoffLabel: string;
      offeredFareVnd: number;
      referenceFareVnd: number;
      vehicleClassCode: string;
      agreedFareVnd: number | null;
      discountVnd: number;
      voucherCode: string | null;
      voucherSponsor: 'PLATFORM' | 'MERCHANT' | 'SHARED' | null;
      cancelledBy?: CancelActorName | null;
      status: RideStatusName;
      assignedDriverId: string | null;
      selectedOfferId: string | null;
      expiresAt: Date;
      idempotencyKey: string;
      createdAt: Date;
      updatedAt: Date;
      assignedAt?: Date | null;
      statusChangedAt?: Date | null;
      noShow?: boolean;
      cancelReasonCode?: string | null;
      priorFeesVnd?: number;
      fareRaiseCount?: number;
      repostOfRideId?: string | null;
      offers: Array<{
        id: string;
        rideId: string;
        driverId: string;
        amountVnd: number;
        kind: 'ACCEPT' | 'COUNTER';
        status: RideOfferStatusName;
        expiresAt: Date;
        createdAt: Date;
        editCount?: number;
      }>;
    }>,
    selections: Array<{
      id: string;
      customerId: string;
      idempotencyKey: string;
      rideId: string;
      createdAt: Date;
    }>,
  ): RideLedger {
    return RideLedger.hydrate({
      rides: rides.map((ride) =>
        rideRowFromRecord({
          id: ride.id,
          customerId: ride.customerId,
          pickupLat: ride.pickupLat,
          pickupLng: ride.pickupLng,
          pickupLabel: ride.pickupLabel,
          dropoffLat: ride.dropoffLat,
          dropoffLng: ride.dropoffLng,
          dropoffLabel: ride.dropoffLabel,
          offeredFareVnd: ride.offeredFareVnd,
          referenceFareVnd: ride.referenceFareVnd,
          vehicleClassCode: ride.vehicleClassCode,
          agreedFareVnd: ride.agreedFareVnd,
          discountVnd: ride.discountVnd,
          voucherCode: ride.voucherCode,
          voucherSponsor: ride.voucherSponsor,
          cancelledBy: ride.cancelledBy ?? null,
          status: ride.status,
          assignedDriverId: ride.assignedDriverId,
          selectedOfferId: ride.selectedOfferId,
          expiresAt: ride.expiresAt,
          idempotencyKey: ride.idempotencyKey,
          createdAt: ride.createdAt,
          updatedAt: ride.updatedAt,
          assignedAt: ride.assignedAt ?? null,
          statusChangedAt: ride.statusChangedAt ?? null,
          noShow: ride.noShow ?? false,
          cancelReasonCode: ride.cancelReasonCode ?? null,
          priorFeesVnd: ride.priorFeesVnd ?? 0,
          fareRaiseCount: ride.fareRaiseCount ?? 0,
          repostOfRideId: ride.repostOfRideId ?? null,
          stops: ride.stops ?? [],
          routeVersion: ride.routeVersion ?? 0,
          stopFeeVnd: ride.stopFeeVnd ?? 0,
          stopWaitFreeMinutes: ride.stopWaitFreeMinutes ?? 0,
          stopWaitFeeVndPerMinute: ride.stopWaitFeeVndPerMinute ?? 0,
          waitFeeVnd: ride.waitFeeVnd ?? 0,
        }),
      ),
      offers: rides.flatMap((ride) =>
        ride.offers.map((offer) => ({
          id: offer.id,
          rideId: offer.rideId,
          driverId: offer.driverId,
          amountVnd: offer.amountVnd,
          kind: offer.kind,
          status: offer.status,
          expiresAt: offer.expiresAt,
          createdAt: offer.createdAt,
          editCount: offer.editCount ?? 0,
        })),
      ),
      selections,
    });
  }

  private async lockRides(tx: RideTx, ids: string[]): Promise<void> {
    const sorted = [...new Set(ids)].sort();
    if (sorted.length === 0) {
      return;
    }
    await tx.$queryRaw`
      SELECT id FROM "rides"
      WHERE id IN (${Prisma.join(sorted.map((id) => Prisma.sql`CAST(${id} AS uuid)`))})
      ORDER BY id
      FOR UPDATE
    `;
  }

  private async lockOffers(tx: RideTx, rideId: string): Promise<void> {
    await tx.$queryRaw`
      SELECT id FROM "ride_offers"
      WHERE "rideId" = CAST(${rideId} AS uuid)
      ORDER BY id
      FOR UPDATE
    `;
  }

  // Conditional status update: concurrent transitions cannot both win.
  // Outbox rows for notable status changes are written in the same transaction.
  private async persist(tx: RideTx, ledger: RideLedger): Promise<boolean> {
    const changes = ledger.changes();
    let stale = false;
    const updates = changes.rides.filter((ride) => !ride.isNew);
    const inserts = changes.rides.filter((ride) => ride.isNew);
    const statusEvents: Array<{ id: string; status: RideStatusName; keySuffix?: string }> = [];

    for (const change of updates) {
      if (change.loadedStatus !== null && change.loadedStatus !== change.row.status) {
        const claimed = await tx.ride.updateMany({
          where: { id: change.row.id, status: change.loadedStatus },
          data: ridePatch(change.row),
        });
        if (claimed.count !== 1) {
          if (
            change.loadedStatus === 'NEGOTIATING' &&
            change.row.status === 'ASSIGNED'
          ) {
            throw new RideAssignmentConflict();
          }
          if (change.row.status !== 'EXPIRED') {
            throw new RideAssignmentConflict();
          }
          stale = true;
        } else {
          statusEvents.push({
            id: change.row.id,
            status: change.row.status,
            keySuffix: PRE_TRIP_STATUSES.has(change.row.status) && change.row.assignedDriverId
              ? `${change.row.assignedDriverId}@${change.row.statusChangedAt.getTime()}`
              : undefined,
          });
        }
        continue;
      }
      await tx.ride.update({ where: { id: change.row.id }, data: ridePatch(change.row) });
    }

    for (const change of changes.offers) {
      if (change.isNew) {
        await tx.rideOffer.create({ data: offerData(change.row) });
      } else {
        await tx.rideOffer.update({
          where: { id: change.row.id },
          data: {
            amountVnd: change.row.amountVnd,
            kind: change.row.kind,
            status: change.row.status,
            expiresAt: change.row.expiresAt,
            editCount: change.row.editCount,
          },
        });
      }
    }

    for (const record of changes.cancellations) {
      await tx.driverJobCancellation.create({
        data: {
          entityType: 'RIDE',
          entityId: record.rideId,
          driverId: record.driverId,
          actor: record.actor,
          reasonCode: record.reasonCode.slice(0, 40),
          fromStatus: record.fromStatus,
          createdAt: record.at,
        },
      });
    }

    for (const change of inserts) {
      await tx.ride.create({ data: rideData(change.row) });
    }

    for (const selection of changes.selections) {
      await tx.rideSelection.create({
        data: {
          id: selection.id,
          customerId: selection.customerId,
          idempotencyKey: selection.idempotencyKey,
          rideId: selection.rideId,
          createdAt: selection.createdAt,
        },
      });
    }

    // Stop rows reference the ride, so they go after ride inserts. A changed stop list is
    // rewritten whole (it is short and only edited under the ride row lock).
    for (const entry of changes.stops) {
      await tx.rideStop.deleteMany({ where: { rideId: entry.rideId } });
      if (entry.stops.length > 0) {
        await tx.rideStop.createMany({
          data: entry.stops.map((stop) => ({
            rideId: entry.rideId,
            seq: stop.seq,
            lat: stop.lat,
            lng: stop.lng,
            label: stop.label,
            arrivedAt: stop.arrivedAt,
            departedAt: stop.departedAt,
          })),
        });
      }
    }

    // Fees reference the ride, so they go after ride inserts.
    if (changes.fees.length > 0) {
      await tx.customerFeeCharge.createMany({
        data: changes.fees.map((fee) => ({
          id: fee.id,
          customerId: fee.customerId,
          rideId: fee.rideId,
          kind: fee.kind,
          amountVnd: fee.amountVnd,
          beneficiaryDriverId: fee.beneficiaryDriverId,
          status: fee.status,
          createdAt: fee.createdAt,
        })),
        skipDuplicates: true,
      });
    }

    for (const event of statusEvents) {
      await writeStatusOutbox(tx, {
        aggregateType: 'Ride',
        aggregateId: event.id,
        status: event.status,
        ...(event.keySuffix ? { eventKeySuffix: event.keySuffix } : {}),
      });
    }

    for (const drop of changes.unassignments) {
      await writeRideUnassignedOutbox(tx, drop);
    }

    return stale;
  }
}

/** A ride can come back to these after a drop; their outbox keys carry driver + time. */
const PRE_TRIP_STATUSES = new Set<RideStatusName>(['ASSIGNED', 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED']);

function rideData(row: {
  id: string;
  customerId: string;
  pickupLat: number;
  pickupLng: number;
  pickupLabel: string;
  dropoffLat: number;
  dropoffLng: number;
  dropoffLabel: string;
  offeredFareVnd: number;
  referenceFareVnd: number;
  vehicleClassCode: string;
  agreedFareVnd: number | null;
  status: RideStatusName;
  assignedDriverId: string | null;
  selectedOfferId: string | null;
  expiresAt: Date;
  idempotencyKey: string;
  createdAt: Date;
  statusChangedAt: Date;
  repostOfRideId: string | null;
  stops: unknown[];
  routeVersion: number;
  stopFeeVnd: number;
  stopWaitFreeMinutes: number;
  stopWaitFeeVndPerMinute: number;
}) {
  return {
    stopCount: row.stops.length,
    routeVersion: row.routeVersion,
    stopFeeVnd: row.stopFeeVnd,
    stopWaitFreeMinutes: row.stopWaitFreeMinutes,
    stopWaitFeeVndPerMinute: row.stopWaitFeeVndPerMinute,
    statusChangedAt: row.statusChangedAt,
    repostOfRideId: row.repostOfRideId,
    id: row.id,
    customerId: row.customerId,
    pickupLat: row.pickupLat,
    pickupLng: row.pickupLng,
    pickupLabel: row.pickupLabel,
    dropoffLat: row.dropoffLat,
    dropoffLng: row.dropoffLng,
    dropoffLabel: row.dropoffLabel,
    serviceRegionCode: resolveServiceRegionCode({
      lat: row.pickupLat,
      lng: row.pickupLng,
      label: `${row.pickupLabel} ${row.dropoffLabel}`,
    }),
    offeredFareVnd: row.offeredFareVnd,
    referenceFareVnd: row.referenceFareVnd,
    vehicleClassCode: row.vehicleClassCode,
    agreedFareVnd: row.agreedFareVnd,
    status: row.status,
    assignedDriverId: row.assignedDriverId,
    selectedOfferId: row.selectedOfferId,
    expiresAt: row.expiresAt,
    idempotencyKey: row.idempotencyKey,
    createdAt: row.createdAt,
  };
}

function ridePatch(row: {
  pickupLat: number;
  pickupLng: number;
  pickupLabel: string;
  dropoffLat: number;
  dropoffLng: number;
  dropoffLabel: string;
  offeredFareVnd: number;
  referenceFareVnd: number;
  agreedFareVnd: number | null;
  discountVnd: number;
  voucherCode: string | null;
  voucherSponsor: 'PLATFORM' | 'MERCHANT' | 'SHARED' | null;
  cancelledBy: CancelActorName | null;
  status: RideStatusName;
  assignedDriverId: string | null;
  selectedOfferId: string | null;
  expiresAt: Date;
  assignedAt: Date | null;
  statusChangedAt: Date;
  noShow: boolean;
  cancelReasonCode: string | null;
  priorFeesVnd: number;
  fareRaiseCount: number;
  stops: unknown[];
  routeVersion: number;
  stopFeeVnd: number;
  waitFeeVnd: number;
}) {
  return {
    stopCount: row.stops.length,
    routeVersion: row.routeVersion,
    stopFeeVnd: row.stopFeeVnd,
    waitFeeVnd: row.waitFeeVnd,
    assignedAt: row.assignedAt,
    fareRaiseCount: row.fareRaiseCount,
    statusChangedAt: row.statusChangedAt,
    noShow: row.noShow,
    cancelReasonCode: row.cancelReasonCode,
    priorFeesVnd: row.priorFeesVnd,
    pickupLat: row.pickupLat,
    pickupLng: row.pickupLng,
    pickupLabel: row.pickupLabel,
    dropoffLat: row.dropoffLat,
    dropoffLng: row.dropoffLng,
    dropoffLabel: row.dropoffLabel,
    offeredFareVnd: row.offeredFareVnd,
    referenceFareVnd: row.referenceFareVnd,
    agreedFareVnd: row.agreedFareVnd,
    discountVnd: row.discountVnd,
    voucherCode: row.voucherCode,
    voucherSponsor: row.voucherSponsor,
    cancelledBy: row.cancelledBy,
    status: row.status,
    assignedDriverId: row.assignedDriverId,
    selectedOfferId: row.selectedOfferId,
    expiresAt: row.expiresAt,
  };
}

function offerData(row: {
  id: string;
  rideId: string;
  driverId: string;
  amountVnd: number;
  kind: 'ACCEPT' | 'COUNTER';
  status: RideOfferStatusName;
  expiresAt: Date;
  createdAt: Date;
  editCount: number;
}) {
  return row;
}


function isUniqueConflict(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}
