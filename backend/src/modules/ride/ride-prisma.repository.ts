import { randomUUID } from 'node:crypto';
import {
  normalizeRegionFilter,
  regionCodeOrLabelFallbackWhere,
  resolveServiceRegionCode,
} from '../service-area/service-regions.js';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { writeOpsActionOutbox, writeStatusOutbox } from '../communication/outbox/outbox.write.js';
import { RideRuleError } from './ride.error.js';
import {
  RideLedger,
  rideRowFromRecord,
  type CancelInput,
  type CreateRideInput,
  type DriverLifecycleInput,
  type OfferInput,
  type OpenRideListing,
  type OpsCancelInput,
  type OpsReassignInput,
  type RideSnapshot,
  type RideStatusName,
  type SelectInput,
} from './ride-ledger.js';
import type { OpsInterveneResult, OpsRidePage, RideRepository } from './ride.repository.js';

type RideTx = Prisma.TransactionClient;

class RideAssignmentConflict extends Error {
  constructor() {
    super('Ride assignment conflict');
    this.name = 'RideAssignmentConflict';
  }
}

export class PrismaRideRepository implements RideRepository {
  constructor(private readonly db: PrismaClient) {}

  async create(input: CreateRideInput): Promise<RideSnapshot> {
    let outcome: Awaited<ReturnType<RideLedger['create']>>;
    try {
      outcome = await this.db.$transaction(async (tx) => {
        const ledger = await this.hydrateCustomer(tx, input.customerId, input.idempotencyKey);
        const created = ledger.create(input);
        await this.persist(tx, ledger);
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

  async listOpen(now: Date, limit?: number): Promise<OpenRideListing[]> {
    const take =
      limit !== undefined && Number.isSafeInteger(limit) && limit > 0 ? limit : undefined;
    const rides = await this.db.ride.findMany({
      where: {
        status: 'NEGOTIATING',
        expiresAt: { gt: now },
      },
      orderBy: [{ expiresAt: 'asc' }, { id: 'asc' }],
      ...(take !== undefined ? { take } : {}),
      select: {
        id: true,
        pickupLat: true,
        pickupLng: true,
        pickupLabel: true,
        dropoffLat: true,
        dropoffLng: true,
        dropoffLabel: true,
        offeredFareVnd: true,
        referenceFareVnd: true,
        expiresAt: true,
        _count: { select: { offers: true } },
      },
    });
    return rides.map((ride) => ({
      id: ride.id,
      status: 'NEGOTIATING',
      pickup: { lat: ride.pickupLat, lng: ride.pickupLng, label: ride.pickupLabel },
      dropoff: { lat: ride.dropoffLat, lng: ride.dropoffLng, label: ride.dropoffLabel },
      offeredFareVnd: ride.offeredFareVnd,
      referenceFareVnd: ride.referenceFareVnd,
      expiresAt: ride.expiresAt,
      offerCount: ride._count.offers,
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
                  status: { in: ['ASSIGNED', 'PICKED_UP'] },
                },
              }),
            ]);
            if (activeRides + activeFood >= maxJobs) {
              throw new RideRuleError('DRIVER_AT_CAPACITY');
            }
          }
        }

        const selected = ledger.select(input);
        await this.persist(tx, ledger);
        return selected;
      });
    } catch (error) {
      if (error instanceof RideRuleError) {
        throw error;
      }
      if (error instanceof RideAssignmentConflict || isUniqueConflict(error)) {
        const prior = await this.db.rideSelection.findUnique({
          where: {
            customerId_idempotencyKey: {
              customerId: input.customerId,
              idempotencyKey: input.idempotencyKey,
            },
          },
        });
        if (prior) {
          const ride = await this.findById(prior.rideId, input.now);
          if (ride && ride.customerId === input.customerId) {
            return ride;
          }
        }
        throw new RideRuleError('RIDE_OFFER_UNAVAILABLE');
      }
      throw error;
    }
    if (outcome.error || !outcome.ride) {
      throw new RideRuleError(outcome.error ?? 'RIDE_NOT_FOUND');
    }
    return outcome.ride;
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
        include: { offers: true },
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
        include: { offers: true },
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

  complete(input: DriverLifecycleInput): Promise<RideSnapshot> {
    return this.driverLifecycle(input, (ledger) => ledger.complete(input));
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

  private async driverLifecycle(
    input: DriverLifecycleInput,
    apply: (ledger: RideLedger) => Awaited<ReturnType<RideLedger['markEnRoute']>>,
  ): Promise<RideSnapshot> {
    let outcome: Awaited<ReturnType<RideLedger['markEnRoute']>>;
    try {
      outcome = await this.db.$transaction(async (tx) => {
        const ledger = await this.hydrateRide(tx, input.rideId);
        if (!ledger) {
          return { error: 'RIDE_NOT_FOUND' as const };
        }
        const next = apply(ledger);
        await this.persist(tx, ledger);
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
      include: { offers: true },
    });
    return this.ledgerFrom(rides, []);
  }

  private async hydrateRide(tx: RideTx, rideId: string): Promise<RideLedger | null> {
    await this.lockRides(tx, [rideId]);
    const ride = await tx.ride.findUnique({ where: { id: rideId }, include: { offers: true } });
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
      include: { offers: true },
    });
    return this.ledgerFrom(rides, selection ? [selection] : []);
  }

  private ledgerFrom(
    rides: Array<{
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
      agreedFareVnd: number | null;
      status: RideStatusName;
      assignedDriverId: string | null;
      selectedOfferId: string | null;
      expiresAt: Date;
      idempotencyKey: string;
      createdAt: Date;
      updatedAt: Date;
      offers: Array<{
        id: string;
        rideId: string;
        driverId: string;
        amountVnd: number;
        kind: 'ACCEPT' | 'COUNTER';
        status: 'PENDING' | 'SELECTED' | 'LOST';
        expiresAt: Date;
        createdAt: Date;
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
          agreedFareVnd: ride.agreedFareVnd,
          status: ride.status,
          assignedDriverId: ride.assignedDriverId,
          selectedOfferId: ride.selectedOfferId,
          expiresAt: ride.expiresAt,
          idempotencyKey: ride.idempotencyKey,
          createdAt: ride.createdAt,
          updatedAt: ride.updatedAt,
        }),
      ),
      offers: rides.flatMap((ride) => ride.offers),
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
    const statusEvents: Array<{ id: string; status: RideStatusName }> = [];

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
          statusEvents.push({ id: change.row.id, status: change.row.status });
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
          },
        });
      }
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

    for (const event of statusEvents) {
      await writeStatusOutbox(tx, {
        aggregateType: 'Ride',
        aggregateId: event.id,
        status: event.status,
      });
    }

    return stale;
  }
}

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
  agreedFareVnd: number | null;
  status: RideStatusName;
  assignedDriverId: string | null;
  selectedOfferId: string | null;
  expiresAt: Date;
  idempotencyKey: string;
  createdAt: Date;
}) {
  return {
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
  status: RideStatusName;
  assignedDriverId: string | null;
  selectedOfferId: string | null;
  expiresAt: Date;
}) {
  return {
    pickupLat: row.pickupLat,
    pickupLng: row.pickupLng,
    pickupLabel: row.pickupLabel,
    dropoffLat: row.dropoffLat,
    dropoffLng: row.dropoffLng,
    dropoffLabel: row.dropoffLabel,
    offeredFareVnd: row.offeredFareVnd,
    referenceFareVnd: row.referenceFareVnd,
    agreedFareVnd: row.agreedFareVnd,
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
  status: 'PENDING' | 'SELECTED' | 'LOST';
  expiresAt: Date;
  createdAt: Date;
}) {
  return row;
}

function isUniqueConflict(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}
