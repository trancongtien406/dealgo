import { cancellationCountsAgainstDriver } from '../../shared/cancel-actor.js';
import type { CancelActorName } from '../../shared/cancel-actor.js';
import type { DriverJobCounts } from '../../shared/driver-job-counts.js';
import { randomUUID } from 'node:crypto';
import {
  getServiceRegion,
  normalizeRegionFilter,
} from '../service-area/service-regions.js';
import type { RideRuleCode } from './ride.error.js';

export type RideStatusName =
  | 'NEGOTIATING'
  | 'ASSIGNED'
  | 'DRIVER_EN_ROUTE'
  | 'DRIVER_ARRIVED'
  | 'IN_TRIP'
  | 'COMPLETED'
  | 'CANCELLED'
  | 'EXPIRED';
export type { CancelActorName };
export type RideOfferKindName = 'ACCEPT' | 'COUNTER';
export type RideOfferStatusName = 'PENDING' | 'SELECTED' | 'LOST';

export const RIDE_PRE_TRIP_STATUSES = [
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
] as const satisfies readonly RideStatusName[];

const PRE_TRIP = new Set<string>(RIDE_PRE_TRIP_STATUSES);

export type GeoPoint = {
  lat: number;
  lng: number;
  label: string;
};

export type RideOfferSnapshot = {
  id: string;
  driverId: string;
  amountVnd: number;
  kind: RideOfferKindName;
  status: RideOfferStatusName;
  expiresAt: Date;
};

export type RideSnapshot = {
  id: string;
  customerId: string;
  status: RideStatusName;
  pickup: GeoPoint;
  dropoff: GeoPoint;
  offeredFareVnd: number;
  referenceFareVnd: number;
  agreedFareVnd: number | null;
  /** DEC-PROD-024: voucher discount reserved at offer selection (0 when none). */
  discountVnd: number;
  voucherCode: string | null;
  /** Internal funding snapshot; never published to clients. */
  voucherSponsor: RideVoucherSponsor | null;
  cancelledBy: CancelActorName | null;
  assignedDriverId: string | null;
  selectedOfferId: string | null;
  expiresAt: Date;
  updatedAt: Date;
  offers: RideOfferSnapshot[];
};

export type RideVoucherSponsor = 'PLATFORM' | 'MERCHANT' | 'SHARED';

export type RideVoucherApplied = {
  code: string;
  discountVnd: number;
  sponsor: RideVoucherSponsor;
};

/** Driver history window: finished jobs, newest first. */
export type DriverHistoryWindow = {
  /** Inclusive upper bound on updatedAt (cursor). */
  before?: Date;
  /** Inclusive lower bound on updatedAt. */
  since?: Date;
  limit: number;
};

export const DRIVER_HISTORY_RIDE_STATUSES = ['COMPLETED', 'CANCELLED'] as const;

export type LedgerOutcome =
  | { error: RideRuleCode; ride?: undefined }
  | { error?: undefined; ride: RideSnapshot };

export type CreateRideInput = {
  customerId: string;
  idempotencyKey: string;
  pickup: GeoPoint;
  dropoff: GeoPoint;
  offeredFareVnd: number;
  referenceFareVnd: number;
  expiresAt: Date;
  now: Date;
};

export type OfferInput = {
  rideId: string;
  driverId: string;
  amountVnd: number;
  expiresAt: Date;
  now: Date;
  /** When set, blocks new driver offers once this many offers exist on the ride. */
  maxRounds?: number;
};

export type SelectInput = {
  rideId: string;
  customerId: string;
  offerId: string;
  idempotencyKey: string;
  now: Date;
  /** Max concurrent capacity checked by repositories before assignment. */
  maxConcurrentJobs?: number;
  /** DEC-PROD-024: optional voucher redeemed in the same transaction as the selection. */
  voucherCode?: string;
};

export type CancelInput = {
  rideId: string;
  customerId: string;
  now: Date;
};

export type OpsCancelInput = {
  rideId: string;
  now: Date;
};

export type OpsReassignInput = {
  rideId: string;
  now: Date;
};

const OPS_CANCELLABLE = new Set<string>([
  'NEGOTIATING',
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
]);

const OPS_REASSIGNABLE = new Set<string>(RIDE_PRE_TRIP_STATUSES);

export type DriverLifecycleInput = {
  rideId: string;
  driverId: string;
  now: Date;
};

export type OpenRideListing = {
  id: string;
  status: 'NEGOTIATING';
  pickup: GeoPoint;
  dropoff: GeoPoint;
  offeredFareVnd: number;
  referenceFareVnd: number;
  expiresAt: Date;
  offerCount: number;
};

type RideRow = {
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
  discountVnd: number;
  voucherCode: string | null;
  voucherSponsor: RideVoucherSponsor | null;
  cancelledBy: CancelActorName | null;
  status: RideStatusName;
  loadedStatus: RideStatusName | null;
  assignedDriverId: string | null;
  selectedOfferId: string | null;
  expiresAt: Date;
  idempotencyKey: string;
  createdAt: Date;
  updatedAt: Date;
};

type OfferRow = {
  id: string;
  rideId: string;
  driverId: string;
  amountVnd: number;
  kind: RideOfferKindName;
  status: RideOfferStatusName;
  expiresAt: Date;
  createdAt: Date;
};

type SelectionRow = {
  id: string;
  customerId: string;
  idempotencyKey: string;
  rideId: string;
  createdAt: Date;
};

export type RideChange = {
  row: RideRow;
  isNew: boolean;
  loadedStatus: RideStatusName | null;
};

export type OfferChange = {
  row: OfferRow;
  isNew: boolean;
};

export function selectionKey(customerId: string, idempotencyKey: string): string {
  return `${customerId}:${idempotencyKey}`;
}

export class RideLedger {
  private readonly rides = new Map<string, RideRow>();
  private readonly offers = new Map<string, OfferRow>();
  private readonly selections = new Map<string, SelectionRow>();
  private readonly dirtyRideIds = new Set<string>();
  private readonly dirtyOfferIds = new Set<string>();
  private readonly newRideIds = new Set<string>();
  private readonly newOfferIds = new Set<string>();
  private readonly newSelectionKeys = new Set<string>();

  static hydrate(input: {
    rides: RideRow[];
    offers: OfferRow[];
    selections: SelectionRow[];
  }): RideLedger {
    const ledger = new RideLedger();
    for (const ride of input.rides) {
      ledger.rides.set(ride.id, ride);
    }
    for (const offer of input.offers) {
      ledger.offers.set(offer.id, offer);
    }
    for (const selection of input.selections) {
      ledger.selections.set(selectionKey(selection.customerId, selection.idempotencyKey), selection);
    }
    return ledger;
  }

  create(input: CreateRideInput): LedgerOutcome {
    const existing = [...this.rides.values()].find(
      (ride) =>
        ride.customerId === input.customerId && ride.idempotencyKey === input.idempotencyKey,
    );
    if (existing) {
      this.expireIfDue(existing, input.now);
      return { ride: this.snapshot(existing) };
    }

    const open = [...this.rides.values()].find(
      (ride) => ride.customerId === input.customerId && ride.status === 'NEGOTIATING',
    );
    if (open) {
      if (open.expiresAt.getTime() <= input.now.getTime()) {
        this.expireIfDue(open, input.now);
      } else {
        return { error: 'RIDE_ALREADY_OPEN' };
      }
    }

    const ride: RideRow = {
      id: randomUUID(),
      customerId: input.customerId,
      pickupLat: input.pickup.lat,
      pickupLng: input.pickup.lng,
      pickupLabel: input.pickup.label,
      dropoffLat: input.dropoff.lat,
      dropoffLng: input.dropoff.lng,
      dropoffLabel: input.dropoff.label,
      offeredFareVnd: input.offeredFareVnd,
      referenceFareVnd: input.referenceFareVnd,
      agreedFareVnd: null,
      discountVnd: 0,
      voucherCode: null,
      voucherSponsor: null,
      cancelledBy: null,
      status: 'NEGOTIATING',
      loadedStatus: null,
      assignedDriverId: null,
      selectedOfferId: null,
      expiresAt: input.expiresAt,
      idempotencyKey: input.idempotencyKey,
      createdAt: input.now,
      updatedAt: input.now,
    };
    this.rides.set(ride.id, ride);
    this.newRideIds.add(ride.id);
    this.dirtyRideIds.add(ride.id);
    return { ride: this.snapshot(ride) };
  }

  read(id: string, now: Date): RideSnapshot | null {
    const ride = this.rides.get(id);
    if (!ride) {
      return null;
    }
    this.expireIfDue(ride, now);
    return this.snapshot(ride);
  }

  listOpen(now: Date, limit?: number): OpenRideListing[] {
    const nowMs = now.getTime();
    const rows = [...this.rides.values()]
      .filter((ride) => ride.status === 'NEGOTIATING' && ride.expiresAt.getTime() > nowMs)
      .sort(
        (left, right) =>
          left.expiresAt.getTime() - right.expiresAt.getTime() || left.id.localeCompare(right.id),
      )
      .map((ride) => ({
        id: ride.id,
        status: 'NEGOTIATING' as const,
        pickup: { lat: ride.pickupLat, lng: ride.pickupLng, label: ride.pickupLabel },
        dropoff: { lat: ride.dropoffLat, lng: ride.dropoffLng, label: ride.dropoffLabel },
        offeredFareVnd: ride.offeredFareVnd,
        referenceFareVnd: ride.referenceFareVnd,
        expiresAt: new Date(ride.expiresAt),
        offerCount: this.countOffers(ride.id),
      }));
    if (limit !== undefined && Number.isSafeInteger(limit) && limit > 0) {
      return rows.slice(0, limit);
    }
    return rows;
  }

  offer(input: OfferInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    if (ride.customerId === input.driverId) {
      return { error: 'RIDE_SELF_OFFER' };
    }
    this.expireIfDue(ride, input.now);
    if (ride.status !== 'NEGOTIATING') {
      return { error: 'RIDE_OFFER_UNAVAILABLE' };
    }

    const kind: RideOfferKindName =
      input.amountVnd === ride.offeredFareVnd ? 'ACCEPT' : 'COUNTER';
    const existing = [...this.offers.values()].find(
      (offer) => offer.rideId === ride.id && offer.driverId === input.driverId,
    );
    if (existing) {
      if (existing.status !== 'PENDING') {
        return { error: 'RIDE_OFFER_UNAVAILABLE' };
      }
      existing.amountVnd = input.amountVnd;
      existing.kind = kind;
      existing.expiresAt = input.expiresAt;
      this.dirtyOfferIds.add(existing.id);
      return { ride: this.snapshot(ride) };
    }

    const maxRounds = input.maxRounds;
    if (
      maxRounds !== undefined &&
      Number.isSafeInteger(maxRounds) &&
      maxRounds > 0 &&
      this.countOffers(ride.id) >= maxRounds
    ) {
      return { error: 'RIDE_NEGOTIATION_ROUNDS_EXCEEDED' };
    }

    const created: OfferRow = {
      id: randomUUID(),
      rideId: ride.id,
      driverId: input.driverId,
      amountVnd: input.amountVnd,
      kind,
      status: 'PENDING',
      expiresAt: input.expiresAt,
      createdAt: input.now,
    };
    this.offers.set(created.id, created);
    this.newOfferIds.add(created.id);
    this.dirtyOfferIds.add(created.id);
    return { ride: this.snapshot(ride) };
  }

  select(input: SelectInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride || ride.customerId !== input.customerId) {
      return { error: 'RIDE_NOT_FOUND' };
    }

    const prior = this.selections.get(selectionKey(input.customerId, input.idempotencyKey));
    if (prior) {
      const assigned = this.rides.get(prior.rideId);
      if (!assigned) {
        return { error: 'RIDE_NOT_FOUND' };
      }
      this.expireIfDue(assigned, input.now);
      return { ride: this.snapshot(assigned) };
    }

    const offer = this.offers.get(input.offerId);
    if (!offer || offer.rideId !== ride.id) {
      return { error: 'RIDE_OFFER_UNAVAILABLE' };
    }
    if (offer.expiresAt.getTime() <= input.now.getTime()) {
      this.expireIfDue(ride, input.now);
      return { error: 'RIDE_OFFER_EXPIRED' };
    }

    this.expireIfDue(ride, input.now);
    if (ride.status !== 'NEGOTIATING' || offer.status !== 'PENDING') {
      return { error: 'RIDE_OFFER_UNAVAILABLE' };
    }

    const maxJobs = input.maxConcurrentJobs ?? 1;
    const activeForDriver = [...this.rides.values()].filter(
      (row) =>
        row.assignedDriverId === offer.driverId &&
        (row.status === 'ASSIGNED' ||
          row.status === 'DRIVER_EN_ROUTE' ||
          row.status === 'DRIVER_ARRIVED' ||
          row.status === 'IN_TRIP'),
    ).length;
    if (activeForDriver >= maxJobs) {
      return { error: 'DRIVER_AT_CAPACITY' };
    }

    ride.status = 'ASSIGNED';
    ride.agreedFareVnd = offer.amountVnd;
    ride.assignedDriverId = offer.driverId;
    ride.selectedOfferId = offer.id;
    ride.updatedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    offer.status = 'SELECTED';
    this.dirtyOfferIds.add(offer.id);
    for (const other of this.offers.values()) {
      if (other.rideId === ride.id && other.id !== offer.id && other.status === 'PENDING') {
        other.status = 'LOST';
        this.dirtyOfferIds.add(other.id);
      }
    }

    const selection: SelectionRow = {
      id: randomUUID(),
      customerId: input.customerId,
      idempotencyKey: input.idempotencyKey,
      rideId: ride.id,
      createdAt: input.now,
    };
    this.selections.set(selectionKey(input.customerId, input.idempotencyKey), selection);
    this.newSelectionKeys.add(selectionKey(input.customerId, input.idempotencyKey));
    return { ride: this.snapshot(ride) };
  }

  /** True when this customer key already selected an offer (replays must not redeem again). */
  hasSelection(customerId: string, idempotencyKey: string): boolean {
    return this.selections.has(selectionKey(customerId, idempotencyKey));
  }

  /** Amount the ride would be agreed at if `offerId` were selected now (voucher quote). */
  offerAmount(rideId: string, offerId: string): number | null {
    const offer = this.offers.get(offerId);
    return offer && offer.rideId === rideId ? offer.amountVnd : null;
  }

  /** DEC-PROD-024: snapshot the voucher reserved for an assigned ride. */
  applyVoucher(rideId: string, voucher: RideVoucherApplied): RideSnapshot | null {
    const ride = this.rides.get(rideId);
    if (!ride || ride.agreedFareVnd === null) {
      return null;
    }
    ride.discountVnd = Math.min(Math.max(0, voucher.discountVnd), ride.agreedFareVnd);
    ride.voucherCode = voucher.code;
    ride.voucherSponsor = voucher.sponsor;
    this.dirtyRideIds.add(ride.id);
    return this.snapshot(ride);
  }

  cancel(input: CancelInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride || ride.customerId !== input.customerId) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    this.expireIfDue(ride, input.now);
    if (ride.status === 'NEGOTIATING' || PRE_TRIP.has(ride.status)) {
      ride.status = 'CANCELLED';
      ride.cancelledBy = 'CUSTOMER';
      ride.updatedAt = input.now;
      this.dirtyRideIds.add(ride.id);
      return { ride: this.snapshot(ride) };
    }
    return { error: 'RIDE_NOT_CANCELLABLE' };
  }

  opsCancel(input: OpsCancelInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    this.expireIfDue(ride, input.now);
    if (!OPS_CANCELLABLE.has(ride.status)) {
      return { error: 'RIDE_NOT_CANCELLABLE' };
    }
    ride.status = 'CANCELLED';
    ride.cancelledBy = 'OPS';
    ride.updatedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    return { ride: this.snapshot(ride) };
  }

  /** Clear assignment back to NEGOTIATING while still pre-trip. */
  opsReassign(input: OpsReassignInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    this.expireIfDue(ride, input.now);
    if (!OPS_REASSIGNABLE.has(ride.status)) {
      return { error: 'RIDE_STATUS_CONFLICT' };
    }
    if (ride.selectedOfferId) {
      const offer = this.offers.get(ride.selectedOfferId);
      if (offer) {
        offer.status = 'LOST';
        this.dirtyOfferIds.add(offer.id);
      }
      ride.selectedOfferId = null;
    }
    ride.assignedDriverId = null;
    ride.agreedFareVnd = null;
    // The reserved voucher is released by the repository; the next selection may apply one again.
    ride.discountVnd = 0;
    ride.voucherCode = null;
    ride.voucherSponsor = null;
    ride.status = 'NEGOTIATING';
    ride.updatedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    return { ride: this.snapshot(ride) };
  }

  listForCustomer(
    customerId: string,
    page: number,
    limit: number,
    now: Date,
  ): { items: RideSnapshot[]; total: number } {
    const rows = [...this.rides.values()]
      .filter((ride) => ride.customerId === customerId)
      .sort(
        (left, right) =>
          right.createdAt.getTime() - left.createdAt.getTime() || left.id.localeCompare(right.id),
      );
    for (const ride of rows) {
      this.expireIfDue(ride, now);
    }
    const total = rows.length;
    const start = (page - 1) * limit;
    return {
      items: rows.slice(start, start + limit).map((ride) => this.snapshot(ride)),
      total,
    };
  }

  /** COMPLETED vs all terminal rides per assigned driver (DEC-PROD-034). */
  countFinishedForDrivers(driverIds: readonly string[]): Map<string, DriverJobCounts> {
    const wanted = new Set(driverIds);
    const statuses: readonly string[] = DRIVER_HISTORY_RIDE_STATUSES;
    const counts = new Map<string, DriverJobCounts>();
    for (const ride of this.rides.values()) {
      const driverId = ride.assignedDriverId;
      if (
        !driverId ||
        !wanted.has(driverId) ||
        !statuses.includes(ride.status) ||
        !cancellationCountsAgainstDriver(ride.status, ride.cancelledBy)
      ) {
        continue;
      }
      const current = counts.get(driverId) ?? { completed: 0, finished: 0 };
      current.finished += 1;
      if (ride.status === 'COMPLETED') {
        current.completed += 1;
      }
      counts.set(driverId, current);
    }
    return counts;
  }

  listFinishedForDriver(driverId: string, window: DriverHistoryWindow): RideSnapshot[] {
    const statuses: readonly string[] = DRIVER_HISTORY_RIDE_STATUSES;
    return [...this.rides.values()]
      .filter(
        (ride) =>
          ride.assignedDriverId === driverId &&
          statuses.includes(ride.status) &&
          (!window.before || ride.updatedAt.getTime() <= window.before.getTime()) &&
          (!window.since || ride.updatedAt.getTime() >= window.since.getTime()),
      )
      .sort(
        (left, right) =>
          right.updatedAt.getTime() - left.updatedAt.getTime() || right.id.localeCompare(left.id),
      )
      .slice(0, window.limit)
      .map((ride) => this.snapshot(ride));
  }

  markEnRoute(input: DriverLifecycleInput): LedgerOutcome {
    return this.driverTransition(input, 'ASSIGNED', 'DRIVER_EN_ROUTE');
  }

  markArrived(input: DriverLifecycleInput): LedgerOutcome {
    return this.driverTransition(input, 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED');
  }

  startTrip(input: DriverLifecycleInput): LedgerOutcome {
    return this.driverTransition(input, 'DRIVER_ARRIVED', 'IN_TRIP');
  }

  complete(input: DriverLifecycleInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    if (ride.assignedDriverId !== input.driverId) {
      return { error: 'RIDE_NOT_ASSIGNED_DRIVER' };
    }
    if (ride.status !== 'IN_TRIP') {
      return { error: 'RIDE_STATUS_CONFLICT' };
    }
    if (ride.agreedFareVnd === null) {
      return { error: 'RIDE_STATUS_CONFLICT' };
    }
    ride.status = 'COMPLETED';
    ride.updatedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    return { ride: this.snapshot(ride) };
  }

  private driverTransition(
    input: DriverLifecycleInput,
    from: RideStatusName,
    to: RideStatusName,
  ): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    if (ride.assignedDriverId !== input.driverId) {
      return { error: 'RIDE_NOT_ASSIGNED_DRIVER' };
    }
    if (ride.status !== from) {
      return { error: 'RIDE_STATUS_CONFLICT' };
    }
    ride.status = to;
    ride.updatedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    return { ride: this.snapshot(ride) };
  }

  listPage(
    page: number,
    limit: number,
    now: Date,
    filter?: { status?: string; q?: string; zone?: string; serviceType?: string },
  ): { items: RideSnapshot[]; total: number } {
    let rows = [...this.rides.values()].sort(
      (left, right) =>
        right.createdAt.getTime() - left.createdAt.getTime() || left.id.localeCompare(right.id),
    );
    for (const ride of rows) {
      this.expireIfDue(ride, now);
    }
    if (filter?.status && filter.status !== "ALL") {
      const targetStatus = filter.status.toUpperCase();
      rows = rows.filter((r) => r.status.toUpperCase() === targetStatus);
    }
    if (filter?.zone && filter.zone !== "ALL") {
      const code = normalizeRegionFilter(filter.zone);
      if (code) {
        const label =
          getServiceRegion(code)?.label.toLowerCase() ?? code.toLowerCase();
        rows = rows.filter(
          (r) =>
            r.pickupLabel.toLowerCase().includes(label) ||
            r.dropoffLabel.toLowerCase().includes(label),
        );
      }
    }
    if (filter?.q && filter.q.trim()) {
      const q = filter.q.trim().toLowerCase();
      rows = rows.filter((r) => {
        return (
          r.id.toLowerCase().includes(q) ||
          r.customerId.toLowerCase().includes(q) ||
          (r.assignedDriverId && r.assignedDriverId.toLowerCase().includes(q)) ||
          r.pickupLabel.toLowerCase().includes(q) ||
          r.dropoffLabel.toLowerCase().includes(q)
        );
      });
    }
    const total = rows.length;
    const start = (page - 1) * limit;
    return {
      items: rows.slice(start, start + limit).map((ride) => this.snapshot(ride)),
      total,
    };
  }

  changes(): { rides: RideChange[]; offers: OfferChange[]; selections: SelectionRow[] } {
    const rides: RideChange[] = [];
    for (const id of this.dirtyRideIds) {
      const row = this.rides.get(id);
      if (!row) {
        continue;
      }
      rides.push({
        row,
        isNew: this.newRideIds.has(id),
        loadedStatus: row.loadedStatus,
      });
    }
    const offers: OfferChange[] = [];
    for (const id of this.dirtyOfferIds) {
      const row = this.offers.get(id);
      if (!row) {
        continue;
      }
      offers.push({ row, isNew: this.newOfferIds.has(id) });
    }
    const selections = [...this.newSelectionKeys]
      .map((key) => this.selections.get(key))
      .filter((selection): selection is SelectionRow => selection !== undefined);
    return { rides, offers, selections };
  }

  private countOffers(rideId: string): number {
    let count = 0;
    for (const offer of this.offers.values()) {
      if (offer.rideId === rideId) {
        count += 1;
      }
    }
    return count;
  }

  expireDue(now: Date): string[] {
    const expired: string[] = [];
    for (const ride of this.rides.values()) {
      if (ride.status === 'NEGOTIATING' && ride.expiresAt.getTime() <= now.getTime()) {
        ride.status = 'EXPIRED';
        ride.updatedAt = now;
        this.dirtyRideIds.add(ride.id);
        expired.push(ride.id);
      }
    }
    return expired.sort();
  }

  private expireIfDue(ride: RideRow, now: Date): void {
    if (ride.status === 'NEGOTIATING' && ride.expiresAt.getTime() <= now.getTime()) {
      ride.status = 'EXPIRED';
      ride.updatedAt = now;
      this.dirtyRideIds.add(ride.id);
    }
  }

  private snapshot(ride: RideRow): RideSnapshot {
    const offers = [...this.offers.values()]
      .filter((offer) => offer.rideId === ride.id)
      .sort(
        (left, right) =>
          left.createdAt.getTime() - right.createdAt.getTime() || left.id.localeCompare(right.id),
      );
    return {
      id: ride.id,
      customerId: ride.customerId,
      status: ride.status,
      pickup: { lat: ride.pickupLat, lng: ride.pickupLng, label: ride.pickupLabel },
      dropoff: { lat: ride.dropoffLat, lng: ride.dropoffLng, label: ride.dropoffLabel },
      offeredFareVnd: ride.offeredFareVnd,
      referenceFareVnd: ride.referenceFareVnd,
      agreedFareVnd: ride.agreedFareVnd,
      discountVnd: ride.discountVnd,
      voucherCode: ride.voucherCode,
      voucherSponsor: ride.voucherSponsor,
      cancelledBy: ride.cancelledBy,
      assignedDriverId: ride.assignedDriverId,
      selectedOfferId: ride.selectedOfferId,
      expiresAt: new Date(ride.expiresAt),
      updatedAt: new Date(ride.updatedAt),
      offers: offers.map((offer) => ({
        id: offer.id,
        driverId: offer.driverId,
        amountVnd: offer.amountVnd,
        kind: offer.kind,
        status: offer.status,
        expiresAt: new Date(offer.expiresAt),
      })),
    };
  }
}

export function rideRowFromRecord(input: {
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
  discountVnd?: number;
  voucherCode?: string | null;
  voucherSponsor?: RideVoucherSponsor | null;
  cancelledBy?: CancelActorName | null;
  status: RideStatusName;
  assignedDriverId: string | null;
  selectedOfferId: string | null;
  expiresAt: Date;
  idempotencyKey: string;
  createdAt: Date;
  updatedAt: Date;
}): RideRow {
  return {
    ...input,
    discountVnd: input.discountVnd ?? 0,
    voucherCode: input.voucherCode ?? null,
    voucherSponsor: input.voucherSponsor ?? null,
    cancelledBy: input.cancelledBy ?? null,
    loadedStatus: input.status,
  };
}

export type { OfferRow, RideRow, SelectionRow };
