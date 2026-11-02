import { inBox, type GeoBox } from '../dispatch/dispatch-filter.js';
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
export type RideOfferStatusName = 'PENDING' | 'SELECTED' | 'LOST' | 'DECLINED' | 'WITHDRAWN';

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

/** Intermediate stop (multi-stop rides), visited in `seq` order between pickup and dropoff. */
export type RideStopSnapshot = {
  seq: number;
  lat: number;
  lng: number;
  label: string;
  arrivedAt: Date | null;
  departedAt: Date | null;
};

/** Stop fee + wait policy snapshot taken at booking (admin edits never touch live rides). */
export type RideStopPolicy = {
  feeVnd: number;
  freeWaitMinutes: number;
  waitFeeVndPerMinute: number;
};

export type RideOfferSnapshot = {
  id: string;
  driverId: string;
  amountVnd: number;
  kind: RideOfferKindName;
  status: RideOfferStatusName;
  expiresAt: Date;
  /** Changes after the first offer (RIDE_MAX_OFFER_EDITS_PER_DRIVER). */
  editCount: number;
};

/** A driver gave up an assigned ride (self-cancel or SYSTEM timeout). */
export type DriverCancellationRecord = {
  rideId: string;
  driverId: string;
  actor: 'DRIVER' | 'SYSTEM' | 'OPS';
  reasonCode: string;
  fromStatus: RideStatusName;
  at: Date;
};

/** A driver lost an assigned ride (timeout, own drop or ops reassign); they and the customer are told. */
export type RideUnassignment = {
  rideId: string;
  driverId: string;
  actor: DriverCancellationRecord['actor'];
  reasonCode: string;
  fromStatus: RideStatusName;
  at: Date;
};

export type CustomerFeeKindName = 'LATE_CANCEL' | 'NO_SHOW' | 'PARCEL_RETURN';

/** Fee owed by a customer, collected in the next completed ride's cash. */
export type CustomerFeeRecord = {
  id: string;
  customerId: string;
  rideId: string;
  kind: CustomerFeeKindName;
  amountVnd: number;
  beneficiaryDriverId: string | null;
  status: 'PENDING' | 'COLLECTED' | 'WAIVED';
  collectedRideId: string | null;
  createdAt: Date;
};

export type RideSnapshot = {
  id: string;
  customerId: string;
  status: RideStatusName;
  pickup: GeoPoint;
  dropoff: GeoPoint;
  offeredFareVnd: number;
  referenceFareVnd: number;
  vehicleClassCode: string;
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
  /** Lifecycle fields. */
  createdAt: Date;
  assignedAt: Date | null;
  statusChangedAt: Date;
  noShow: boolean;
  cancelReasonCode: string | null;
  /** Earlier unpaid customer fees collected in this ride's cash (set at completion). */
  priorFeesVnd: number;
  /** Customer fare raises so far (each one opens a new negotiation round). */
  fareRaiseCount: number;
  /**
   * Customer opted in to take the first live ACCEPT at the current offered fare.
   * A counter at any other price still waits for a tap.
   */
  autoAcceptOfferedFare?: boolean;
  /** EXPIRED ride this request re-posts. */
  repostOfRideId: string | null;
  offers: RideOfferSnapshot[];
  /** Intermediate stops in visiting order (empty = single destination). */
  stops: RideStopSnapshot[];
  /** Bumped on every stop edit; offers made on an older version are rejected. */
  routeVersion: number;
  /** Per-stop fee snapshot (already part of referenceFareVnd). */
  stopFeeVnd: number;
  stopWaitFreeMinutes: number;
  stopWaitFeeVndPerMinute: number;
  /** Wait fee charged at completion (cash to the driver). */
  waitFeeVnd: number;
  /** Transient: fee charges collected by this completion (cash hand-over adjustments). */
  collectedFees?: Array<{ id: string; amountVnd: number; beneficiaryDriverId: string | null }>;
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
  /** Required at create — no silent MOTORBIKE default (DG-DEC-VEH-001). */
  vehicleClassCode: string;
  expiresAt: Date;
  now: Date;
  /** EXPIRED ride of the same customer being re-posted. */
  repostOfRideId?: string | null;
  /** Intermediate stops (multi-stop rides; validated by the service). */
  stops?: GeoPoint[];
  stopPolicy?: RideStopPolicy;
};

/** Customer edits stops while negotiating: pending offers die and a new round starts. */
export type UpdateStopsInput = {
  rideId: string;
  customerId: string;
  stops: GeoPoint[];
  dropoff: GeoPoint;
  referenceFareVnd: number;
  offeredFareVnd: number;
  stopFeeVnd: number;
  /** Version the customer edited from (optimistic check; undefined = skip). */
  expectedRouteVersion?: number;
  windowExpiresAt: Date;
  now: Date;
};

/** Assigned driver arrives at / leaves stop `seq` (IN_TRIP, in order, idempotent). */
export type StopEventInput = {
  rideId: string;
  driverId: string;
  seq: number;
  now: Date;
};

export type OfferInput = {
  rideId: string;
  driverId: string;
  amountVnd: number;
  /** Per-offer TTL end; capped at the ride's own expiresAt. */
  expiresAt: Date;
  now: Date;
  /**
   * Cap on live (PENDING, unexpired) offers from different drivers on one ride
   * (setting RIDE_MAX_LIVE_OFFERS_PER_RIDE; 0/undefined = unlimited, as on inDrive).
   */
  maxLiveOffers?: number;
  /** Max price changes per driver within the current round (undefined = unlimited). */
  maxEdits?: number;
  /** Route version the driver saw; a stale one is rejected (RIDE_ROUTE_CHANGED). */
  routeVersion?: number;
};

/** Late-cancel / no-show fee policy resolved from settings by the service. */
export type RideFeePolicy = {
  freeCancelMinutes: number;
  amountVnd: number;
};

export type SetAutoAcceptInput = {
  rideId: string;
  customerId: string;
  enabled: boolean;
  now: Date;
};

export type RaiseFareInput = {
  rideId: string;
  customerId: string;
  amountVnd: number;
  now: Date;
  /** New end of the request window (never shortens the current one). */
  windowExpiresAt: Date;
  /** Max raises per ride (RIDE_MAX_FARE_RAISES_PER_RIDE; 0/undefined = unlimited). */
  maxRaises?: number;
};

export type DeclineOfferInput = {
  rideId: string;
  customerId: string;
  offerId: string;
  now: Date;
};

export type WithdrawOfferInput = {
  rideId: string;
  driverId: string;
  now: Date;
};

export type DriverCancelInput = {
  rideId: string;
  driverId: string;
  reasonCode: string;
  now: Date;
  /** The ride goes back to bidding until this time. */
  windowExpiresAt: Date;
};

export type NoShowInput = {
  rideId: string;
  driverId: string;
  now: Date;
  waitMinutes: number;
  feeVnd: number;
};

export type RideTimeoutPolicy = {
  assignedTimeoutMinutes: number;
  enRouteTimeoutMinutes: number;
};

export type SystemTimeoutInput = {
  rideId: string;
  now: Date;
  policy: RideTimeoutPolicy;
  windowExpiresAt: Date;
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
  /**
   * RIDE-003: rides whose PENDING offers from the newly assigned driver were withdrawn in the
   * selection transaction (called after commit so callers can refresh those offer lists).
   */
  onOffersWithdrawn?: (rideIds: string[]) => void;
};

export type CancelInput = {
  rideId: string;
  customerId: string;
  now: Date;
  /** Late-cancel fee policy; omitted = free cancel. */
  fee?: RideFeePolicy;
};

export type OpsCancelInput = {
  rideId: string;
  now: Date;
};

export type OpsReassignInput = {
  rideId: string;
  now: Date;
  /** Fresh request window for the returned ride (defaults to keeping expiresAt). */
  windowExpiresAt?: Date;
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
  /** complete() only: customer fee booked with the completion (DEC-PROD-071 parcel return fee). */
  customerFee?: { kind: CustomerFeeKindName; amountVnd: number };
};

export type OpenRideListing = {
  id: string;
  /** Internal (customer-rating lookup); never copied into the driver-facing view. */
  customerId: string;
  status: 'NEGOTIATING';
  pickup: GeoPoint;
  dropoff: GeoPoint;
  offeredFareVnd: number;
  referenceFareVnd: number;
  vehicleClassCode: string;
  expiresAt: Date;
  offerCount: number;
  stops: GeoPoint[];
  routeVersion: number;
  /** t82u: priced road distance (km); null/absent for legacy rows. */
  routeDistanceKm?: number | null;
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
  vehicleClassCode: string;
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
  assignedAt: Date | null;
  statusChangedAt: Date;
  noShow: boolean;
  cancelReasonCode: string | null;
  priorFeesVnd: number;
  fareRaiseCount: number;
  autoAcceptOfferedFare: boolean;
  repostOfRideId: string | null;
  stops: StopRow[];
  routeVersion: number;
  stopFeeVnd: number;
  stopWaitFreeMinutes: number;
  stopWaitFeeVndPerMinute: number;
  waitFeeVnd: number;
};

type StopRow = RideStopSnapshot;

type OfferRow = {
  id: string;
  rideId: string;
  driverId: string;
  amountVnd: number;
  kind: RideOfferKindName;
  status: RideOfferStatusName;
  expiresAt: Date;
  createdAt: Date;
  editCount: number;
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
  /** Driver cancellations / fees recorded by this ledger (memory repo keeps them all). */
  private readonly cancellations: DriverCancellationRecord[] = [];
  private readonly fees: CustomerFeeRecord[] = [];
  private newCancellations: DriverCancellationRecord[] = [];
  private newUnassignments: RideUnassignment[] = [];
  private newFees: CustomerFeeRecord[] = [];
  private readonly dirtyFeeIds = new Set<string>();
  /** Rides whose stop rows must be re-written. */
  private readonly dirtyStopRideIds = new Set<string>();

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

  /** Drops a ride created in this ledger session (memory rollback of a failed create hook). */
  discardNew(rideId: string): void {
    if (!this.newRideIds.has(rideId)) return;
    this.rides.delete(rideId);
    this.newRideIds.delete(rideId);
    this.dirtyRideIds.delete(rideId);
    this.dirtyStopRideIds.delete(rideId);
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
      vehicleClassCode: input.vehicleClassCode,
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
      assignedAt: null,
      statusChangedAt: input.now,
      noShow: false,
      cancelReasonCode: null,
      priorFeesVnd: 0,
      fareRaiseCount: 0,
      autoAcceptOfferedFare: false,
      repostOfRideId: input.repostOfRideId ?? null,
      stops: (input.stops ?? []).map((stop, index) => ({
        seq: index + 1,
        lat: stop.lat,
        lng: stop.lng,
        label: stop.label,
        arrivedAt: null,
        departedAt: null,
      })),
      routeVersion: 0,
      stopFeeVnd: input.stops?.length ? (input.stopPolicy?.feeVnd ?? 0) : 0,
      stopWaitFreeMinutes: input.stops?.length ? (input.stopPolicy?.freeWaitMinutes ?? 0) : 0,
      stopWaitFeeVndPerMinute: input.stops?.length ? (input.stopPolicy?.waitFeeVndPerMinute ?? 0) : 0,
      waitFeeVnd: 0,
    };
    this.rides.set(ride.id, ride);
    if (ride.stops.length > 0) {
      this.dirtyStopRideIds.add(ride.id);
    }
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

  listOpen(
    now: Date,
    limit?: number,
    vehicleClassCode?: string,
    area?: GeoBox,
  ): OpenRideListing[] {
    const nowMs = now.getTime();
    const rows = [...this.rides.values()]
      .filter(
        (ride) =>
          ride.status === 'NEGOTIATING' &&
          ride.expiresAt.getTime() > nowMs &&
          (vehicleClassCode === undefined || ride.vehicleClassCode === vehicleClassCode) &&
          (area === undefined || inBox({ lat: ride.pickupLat, lng: ride.pickupLng }, area)),
      )
      .sort(
        (left, right) =>
          left.expiresAt.getTime() - right.expiresAt.getTime() || left.id.localeCompare(right.id),
      )
      .map((ride) => ({
        id: ride.id,
        customerId: ride.customerId,
        status: 'NEGOTIATING' as const,
        pickup: { lat: ride.pickupLat, lng: ride.pickupLng, label: ride.pickupLabel },
        dropoff: { lat: ride.dropoffLat, lng: ride.dropoffLng, label: ride.dropoffLabel },
        offeredFareVnd: ride.offeredFareVnd,
        referenceFareVnd: ride.referenceFareVnd,
        vehicleClassCode: ride.vehicleClassCode,
        expiresAt: new Date(ride.expiresAt),
        offerCount: this.countOffers(ride.id),
        stops: ride.stops.map((stop) => ({ lat: stop.lat, lng: stop.lng, label: stop.label })),
        routeVersion: ride.routeVersion,
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

    if (input.routeVersion !== undefined && input.routeVersion !== ride.routeVersion) {
      return { error: 'RIDE_ROUTE_CHANGED' };
    }
    // A driver accepts the bid or asks for more, never less.
    if (input.amountVnd < ride.offeredFareVnd) {
      return { error: 'RIDE_COUNTER_OUT_OF_RANGE' };
    }
    const kind: RideOfferKindName =
      input.amountVnd === ride.offeredFareVnd ? 'ACCEPT' : 'COUNTER';
    const expiresAt =
      input.expiresAt.getTime() < ride.expiresAt.getTime() ? input.expiresAt : new Date(ride.expiresAt);
    const existing = [...this.offers.values()].find(
      (offer) => offer.rideId === ride.id && offer.driverId === input.driverId,
    );
    const maxLive = input.maxLiveOffers;
    const liveFull =
      maxLive !== undefined &&
      Number.isSafeInteger(maxLive) &&
      maxLive > 0 &&
      this.countLiveOffers(ride.id, input.now, existing?.id) >= maxLive;
    if (existing) {
      // DECLINED (customer said no) and SELECTED stay final for this driver on this ride.
      if (existing.status === 'DECLINED' || existing.status === 'SELECTED') {
        return { error: existing.status === 'DECLINED' ? 'RIDE_OFFER_DECLINED' : 'RIDE_OFFER_UNAVAILABLE' };
      }
      // Only a price change counts as an edit; re-sending the same price after a withdraw /
      // expiry (inDrive "offer again") does not use up the round.
      const priceChanged = existing.amountVnd !== input.amountVnd;
      if (priceChanged && input.maxEdits !== undefined && existing.editCount >= input.maxEdits) {
        return { error: 'RIDE_OFFER_EDIT_LIMIT' };
      }
      if (liveFull) {
        return { error: 'RIDE_LIVE_OFFERS_FULL' };
      }
      existing.amountVnd = input.amountVnd;
      existing.kind = kind;
      existing.expiresAt = expiresAt;
      existing.status = 'PENDING';
      if (priceChanged) {
        existing.editCount += 1;
      }
      this.dirtyOfferIds.add(existing.id);
      return { ride: this.snapshot(ride) };
    }

    if (liveFull) {
      return { error: 'RIDE_LIVE_OFFERS_FULL' };
    }

    const created: OfferRow = {
      id: randomUUID(),
      rideId: ride.id,
      driverId: input.driverId,
      amountVnd: input.amountVnd,
      kind,
      status: 'PENDING',
      expiresAt,
      createdAt: input.now,
      editCount: 0,
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
    ride.assignedAt = input.now;
    ride.statusChangedAt = input.now;
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
      const lateFee = this.lateCancelFee(ride, input);
      ride.status = 'CANCELLED';
      ride.cancelledBy = 'CUSTOMER';
      ride.updatedAt = input.now;
      ride.statusChangedAt = input.now;
      this.dirtyRideIds.add(ride.id);
      this.loseOpenOffers(ride.id);
      if (lateFee > 0) {
        this.recordFee(ride, 'LATE_CANCEL', lateFee, input.now);
      }
      return { ride: this.snapshot(ride) };
    }
    return { error: 'RIDE_NOT_CANCELLABLE' };
  }

  /** Fee when the customer cancels after the free window or on arrival. */
  private lateCancelFee(ride: RideRow, input: CancelInput): number {
    const fee = input.fee;
    if (!fee || fee.amountVnd <= 0 || !ride.assignedDriverId || !PRE_TRIP.has(ride.status)) {
      return 0;
    }
    if (ride.status === 'DRIVER_ARRIVED') {
      return fee.amountVnd;
    }
    const since = (ride.assignedAt ?? ride.statusChangedAt).getTime();
    return input.now.getTime() - since >= fee.freeCancelMinutes * 60_000 ? fee.amountVnd : 0;
  }

  private recordFee(ride: RideRow, kind: CustomerFeeKindName, amountVnd: number, now: Date): void {
    if (this.fees.some((fee) => fee.rideId === ride.id && fee.kind === kind)) {
      return;
    }
    const fee: CustomerFeeRecord = {
      id: randomUUID(),
      customerId: ride.customerId,
      rideId: ride.id,
      kind,
      amountVnd,
      beneficiaryDriverId: ride.assignedDriverId,
      status: 'PENDING',
      collectedRideId: null,
      createdAt: now,
    };
    this.fees.push(fee);
    this.newFees.push(fee);
  }

  /** Pending customer fees known to this ledger (memory repo). */
  pendingFees(customerId: string): CustomerFeeRecord[] {
    return this.fees.filter((fee) => fee.customerId === customerId && fee.status === 'PENDING');
  }

  /** Mark fees collected in `rideId`'s cash; returns the ride with priorFeesVnd set. */
  collectFees(rideId: string, charges: CustomerFeeRecord[], now: Date): void {
    const ride = this.rides.get(rideId);
    if (!ride) {
      return;
    }
    for (const charge of charges) {
      charge.status = 'COLLECTED';
      charge.collectedRideId = rideId;
      this.dirtyFeeIds.add(charge.id);
    }
    ride.priorFeesVnd = charges.reduce((sum, charge) => sum + charge.amountVnd, 0);
    ride.updatedAt = now;
    this.dirtyRideIds.add(ride.id);
  }

  /** Customer opts in or out of taking an exact-price ACCEPT without another tap. */
  setAutoAccept(input: SetAutoAcceptInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride || ride.customerId !== input.customerId) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    this.expireIfDue(ride, input.now);
    if (ride.status !== 'NEGOTIATING') {
      return { error: 'RIDE_NOT_NEGOTIATING' };
    }
    if (ride.autoAcceptOfferedFare !== input.enabled) {
      ride.autoAcceptOfferedFare = input.enabled;
      ride.updatedAt = input.now;
      this.dirtyRideIds.add(ride.id);
    }
    return { ride: this.snapshot(ride) };
  }

  /** Customer raises the bid (inDrive). Increase only; extends the request window. */
  raiseFare(input: RaiseFareInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride || ride.customerId !== input.customerId) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    this.expireIfDue(ride, input.now);
    if (ride.status !== 'NEGOTIATING') {
      return { error: 'RIDE_STATUS_CONFLICT' };
    }
    if (input.amountVnd <= ride.offeredFareVnd) {
      return { error: 'RIDE_FARE_RAISE_INVALID' };
    }
    if (
      input.maxRaises !== undefined &&
      Number.isSafeInteger(input.maxRaises) &&
      input.maxRaises > 0 &&
      ride.fareRaiseCount >= input.maxRaises
    ) {
      return { error: 'RIDE_FARE_RAISE_LIMIT' };
    }
    ride.offeredFareVnd = input.amountVnd;
    ride.fareRaiseCount += 1;
    if (input.windowExpiresAt.getTime() > ride.expiresAt.getTime()) {
      ride.expiresAt = input.windowExpiresAt;
    }
    ride.updatedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    // Live offers below the new bid are lifted to it: a driver never ends up with less.
    // A raise opens a new round — every driver not declined gets their edits back.
    for (const offer of this.offers.values()) {
      if (offer.rideId !== ride.id || offer.status === 'DECLINED') continue;
      if (offer.editCount !== 0) {
        offer.editCount = 0;
        this.dirtyOfferIds.add(offer.id);
      }
      if (offer.status !== 'PENDING') continue;
      if (offer.amountVnd <= input.amountVnd) {
        offer.amountVnd = input.amountVnd;
        offer.kind = 'ACCEPT';
        this.dirtyOfferIds.add(offer.id);
      }
    }
    return { ride: this.snapshot(ride) };
  }

  /**
   * Customer edits the stop list while NEGOTIATING. Every live offer is LOST (it priced the old
   * route), edit budgets reset and the request window restarts — a new round, like a raise.
   * Locked once a driver is chosen.
   */
  updateStops(input: UpdateStopsInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride || ride.customerId !== input.customerId) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    this.expireIfDue(ride, input.now);
    if (ride.status !== 'NEGOTIATING') {
      return { error: 'RIDE_STOPS_LOCKED' };
    }
    if (input.expectedRouteVersion !== undefined && input.expectedRouteVersion !== ride.routeVersion) {
      return { error: 'RIDE_ROUTE_CHANGED' };
    }
    ride.stops = input.stops.map((stop, index) => ({
      seq: index + 1,
      lat: stop.lat,
      lng: stop.lng,
      label: stop.label,
      arrivedAt: null,
      departedAt: null,
    }));
    ride.dropoffLat = input.dropoff.lat;
    ride.dropoffLng = input.dropoff.lng;
    ride.dropoffLabel = input.dropoff.label;
    ride.referenceFareVnd = input.referenceFareVnd;
    ride.offeredFareVnd = input.offeredFareVnd;
    ride.stopFeeVnd = ride.stops.length > 0 ? input.stopFeeVnd : 0;
    ride.routeVersion += 1;
    if (input.windowExpiresAt.getTime() > ride.expiresAt.getTime()) {
      ride.expiresAt = input.windowExpiresAt;
    }
    ride.updatedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    this.dirtyStopRideIds.add(ride.id);
    for (const offer of this.offers.values()) {
      if (offer.rideId !== ride.id || offer.status === 'DECLINED') continue;
      let dirty = false;
      if (offer.status === 'PENDING') {
        offer.status = 'LOST';
        dirty = true;
      }
      if (offer.editCount !== 0) {
        offer.editCount = 0;
        dirty = true;
      }
      if (dirty) this.dirtyOfferIds.add(offer.id);
    }
    return { ride: this.snapshot(ride) };
  }

  /** Driver reached stop `seq` (the first one not yet left). Repeating it is a no-op. */
  arriveStop(input: StopEventInput): LedgerOutcome {
    const found = this.tripStop(input);
    if ('error' in found) return { error: found.error };
    const { ride, stop, next } = found;
    if (stop.arrivedAt) {
      return { ride: this.snapshot(ride) };
    }
    if (next !== stop) {
      return { error: 'RIDE_STOP_OUT_OF_ORDER' };
    }
    stop.arrivedAt = input.now;
    ride.updatedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    this.dirtyStopRideIds.add(ride.id);
    return { ride: this.snapshot(ride) };
  }

  /** Driver leaves stop `seq` after arriving. Repeating it is a no-op. */
  departStop(input: StopEventInput): LedgerOutcome {
    const found = this.tripStop(input);
    if ('error' in found) return { error: found.error };
    const { ride, stop } = found;
    if (stop.departedAt) {
      return { ride: this.snapshot(ride) };
    }
    if (!stop.arrivedAt) {
      return { error: 'RIDE_STOP_OUT_OF_ORDER' };
    }
    stop.departedAt = input.now;
    ride.updatedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    this.dirtyStopRideIds.add(ride.id);
    return { ride: this.snapshot(ride) };
  }

  private tripStop(
    input: StopEventInput,
  ): { error: RideRuleCode } | { ride: RideRow; stop: StopRow; next: StopRow | undefined } {
    const ride = this.rides.get(input.rideId);
    if (!ride) return { error: 'RIDE_NOT_FOUND' };
    if (ride.assignedDriverId !== input.driverId) return { error: 'RIDE_NOT_ASSIGNED_DRIVER' };
    if (ride.status !== 'IN_TRIP') return { error: 'RIDE_STATUS_CONFLICT' };
    const stop = ride.stops.find((candidate) => candidate.seq === input.seq);
    if (!stop) return { error: 'RIDE_NOT_FOUND' };
    return { ride, stop, next: ride.stops.find((candidate) => !candidate.departedAt) };
  }

  /** Customer declines one offer; that driver cannot bid on this ride again. */
  declineOffer(input: DeclineOfferInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride || ride.customerId !== input.customerId) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    this.expireIfDue(ride, input.now);
    const offer = this.offers.get(input.offerId);
    if (!offer || offer.rideId !== ride.id) {
      return { error: 'RIDE_OFFER_UNAVAILABLE' };
    }
    if (ride.status !== 'NEGOTIATING' || offer.status !== 'PENDING') {
      return { error: 'RIDE_OFFER_UNAVAILABLE' };
    }
    offer.status = 'DECLINED';
    this.dirtyOfferIds.add(offer.id);
    return { ride: this.snapshot(ride) };
  }

  /** Driver withdraws a pending offer (may bid again while the ride negotiates). */
  withdrawOffer(input: WithdrawOfferInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    this.expireIfDue(ride, input.now);
    const offer = [...this.offers.values()].find(
      (row) => row.rideId === ride.id && row.driverId === input.driverId,
    );
    if (!offer || ride.status !== 'NEGOTIATING' || offer.status !== 'PENDING') {
      return { error: 'RIDE_OFFER_UNAVAILABLE' };
    }
    offer.status = 'WITHDRAWN';
    this.dirtyOfferIds.add(offer.id);
    return { ride: this.snapshot(ride) };
  }

  /**
   * The assigned driver gives up before the trip. The ride returns to bidding (no auto
   * match) with a fresh window; the cancellation counts in the driver's completion rate.
   */
  driverCancel(input: DriverCancelInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    if (ride.assignedDriverId !== input.driverId) {
      return { error: 'RIDE_NOT_ASSIGNED_DRIVER' };
    }
    if (!PRE_TRIP.has(ride.status)) {
      return { error: 'RIDE_NOT_CANCELLABLE' };
    }
    this.returnToBidding(ride, {
      actor: 'DRIVER',
      reasonCode: input.reasonCode,
      now: input.now,
      windowExpiresAt: input.windowExpiresAt,
    });
    return { ride: this.snapshot(ride) };
  }

  /** Customer no-show after the driver waited at pickup. */
  markNoShow(input: NoShowInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    if (ride.assignedDriverId !== input.driverId) {
      return { error: 'RIDE_NOT_ASSIGNED_DRIVER' };
    }
    if (ride.status !== 'DRIVER_ARRIVED') {
      return { error: 'RIDE_STATUS_CONFLICT' };
    }
    if (input.now.getTime() - ride.statusChangedAt.getTime() < input.waitMinutes * 60_000) {
      return { error: 'RIDE_NO_SHOW_TOO_EARLY' };
    }
    ride.status = 'CANCELLED';
    ride.cancelledBy = 'CUSTOMER';
    ride.noShow = true;
    ride.cancelReasonCode = 'NO_SHOW';
    ride.updatedAt = input.now;
    ride.statusChangedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    if (input.feeVnd > 0) {
      this.recordFee(ride, 'NO_SHOW', input.feeVnd, input.now);
    }
    return { ride: this.snapshot(ride) };
  }

  /** Rides stuck in ASSIGNED / DRIVER_EN_ROUTE past the timeout (worker). */
  listTimeoutCandidates(now: Date, policy: RideTimeoutPolicy): string[] {
    return [...this.rides.values()]
      .filter((ride) => this.timeoutReason(ride, now, policy) !== null)
      .map((ride) => ride.id)
      .sort();
  }

  systemTimeout(input: SystemTimeoutInput): LedgerOutcome {
    const ride = this.rides.get(input.rideId);
    if (!ride) {
      return { error: 'RIDE_NOT_FOUND' };
    }
    const reason = this.timeoutReason(ride, input.now, input.policy);
    if (!reason) {
      return { error: 'RIDE_STATUS_CONFLICT' };
    }
    this.returnToBidding(ride, {
      actor: 'SYSTEM',
      reasonCode: reason,
      now: input.now,
      windowExpiresAt: input.windowExpiresAt,
    });
    return { ride: this.snapshot(ride) };
  }

  private timeoutReason(ride: RideRow, now: Date, policy: RideTimeoutPolicy): string | null {
    const age = now.getTime() - ride.statusChangedAt.getTime();
    if (
      ride.status === 'ASSIGNED' &&
      policy.assignedTimeoutMinutes > 0 &&
      age >= policy.assignedTimeoutMinutes * 60_000
    ) {
      return 'ASSIGNED_TIMEOUT';
    }
    if (
      ride.status === 'DRIVER_EN_ROUTE' &&
      policy.enRouteTimeoutMinutes > 0 &&
      age >= policy.enRouteTimeoutMinutes * 60_000
    ) {
      return 'EN_ROUTE_TIMEOUT';
    }
    return null;
  }

  private returnToBidding(
    ride: RideRow,
    input: { actor: DriverCancellationRecord['actor']; reasonCode: string; now: Date; windowExpiresAt: Date | undefined },
  ): void {
    if (ride.assignedDriverId) {
      this.newUnassignments.push({
        rideId: ride.id,
        driverId: ride.assignedDriverId,
        actor: input.actor,
        reasonCode: input.reasonCode,
        fromStatus: ride.status,
        at: input.now,
      });
    }
    if (ride.assignedDriverId && input.actor !== 'OPS') {
      const record: DriverCancellationRecord = {
        rideId: ride.id,
        driverId: ride.assignedDriverId,
        actor: input.actor,
        reasonCode: input.reasonCode,
        fromStatus: ride.status,
        at: input.now,
      };
      this.cancellations.push(record);
      this.newCancellations.push(record);
    }
    if (ride.selectedOfferId) {
      const offer = this.offers.get(ride.selectedOfferId);
      if (offer) {
        // The driver who dropped the job cannot win it again; ops reassign keeps LOST.
        offer.status = input.actor === 'OPS' ? 'LOST' : 'DECLINED';
        this.dirtyOfferIds.add(offer.id);
      }
      ride.selectedOfferId = null;
    }
    ride.assignedDriverId = null;
    ride.assignedAt = null;
    ride.agreedFareVnd = null;
    // The reserved voucher is released by the repository; the next selection may apply one again.
    ride.discountVnd = 0;
    ride.voucherCode = null;
    ride.voucherSponsor = null;
    ride.status = 'NEGOTIATING';
    ride.cancelReasonCode = input.actor === 'OPS' ? ride.cancelReasonCode : input.reasonCode;
    if (input.windowExpiresAt && input.windowExpiresAt.getTime() > ride.expiresAt.getTime()) {
      ride.expiresAt = input.windowExpiresAt;
    }
    ride.updatedAt = input.now;
    ride.statusChangedAt = input.now;
    this.dirtyRideIds.add(ride.id);
  }

  /** PENDING offers die with the ride (expired / cancelled). */
  private loseOpenOffers(rideId: string): void {
    for (const offer of this.offers.values()) {
      if (offer.rideId === rideId && offer.status === 'PENDING') {
        offer.status = 'LOST';
        this.dirtyOfferIds.add(offer.id);
      }
    }
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
    ride.statusChangedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    this.loseOpenOffers(ride.id);
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
    // A fresh window so the returned ride does not expire immediately.
    this.returnToBidding(ride, {
      actor: 'OPS',
      reasonCode: 'OPS_REASSIGN',
      now: input.now,
      windowExpiresAt: input.windowExpiresAt,
    });
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
    // Assigned jobs the driver gave up (self-cancel / timeout) count as finished, not completed.
    for (const record of this.cancellations) {
      if (!wanted.has(record.driverId)) continue;
      const current = counts.get(record.driverId) ?? { completed: 0, finished: 0 };
      current.finished += 1;
      counts.set(record.driverId, current);
    }
    return counts;
  }

  listIdsForDriverInStatuses(driverId: string, statuses: readonly string[]): string[] {
    return [...this.rides.values()]
      .filter((ride) => ride.assignedDriverId === driverId && statuses.includes(ride.status))
      .map((ride) => ride.id);
  }

  /** When this customer cancelled rides that already had a driver, since `since`. */
  customerCancelTimes(customerId: string, since: Date): Date[] {
    return [...this.rides.values()]
      .filter(
        (ride) =>
          ride.customerId === customerId &&
          ride.status === 'CANCELLED' &&
          ride.cancelledBy === 'CUSTOMER' &&
          ride.assignedDriverId !== null &&
          ride.statusChangedAt.getTime() >= since.getTime(),
      )
      .map((ride) => new Date(ride.statusChangedAt));
  }

  listIdsForCustomerInStatuses(customerId: string, statuses: readonly string[]): string[] {
    return [...this.rides.values()]
      .filter((ride) => ride.customerId === customerId && statuses.includes(ride.status))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .map((ride) => ride.id);
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
    if (ride.stops.some((stop) => !stop.departedAt)) {
      return { error: 'RIDE_STOPS_PENDING' };
    }
    ride.waitFeeVnd = stopWaitFeeVnd(ride.stops, ride.stopWaitFreeMinutes, ride.stopWaitFeeVndPerMinute);
    ride.status = 'COMPLETED';
    ride.updatedAt = input.now;
    ride.statusChangedAt = input.now;
    this.dirtyRideIds.add(ride.id);
    if (input.customerFee && input.customerFee.amountVnd > 0) {
      this.recordFee(ride, input.customerFee.kind, input.customerFee.amountVnd, input.now);
    }
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
    ride.statusChangedAt = input.now;
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

  changes(): {
    rides: RideChange[];
    offers: OfferChange[];
    selections: SelectionRow[];
    cancellations: DriverCancellationRecord[];
    unassignments: RideUnassignment[];
    fees: CustomerFeeRecord[];
    stops: Array<{ rideId: string; stops: RideStopSnapshot[] }>;
  } {
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
    return {
      rides,
      offers,
      selections,
      cancellations: [...this.newCancellations],
      unassignments: [...this.newUnassignments],
      fees: [...this.newFees],
      stops: [...this.dirtyStopRideIds]
        .map((rideId) => ({ rideId, stops: this.rides.get(rideId)?.stops ?? [] }))
        .filter((entry) => this.rides.has(entry.rideId)),
    };
  }

  /** Memory repo: forget what was already "persisted" (the ledger is the store). */
  clearRecorded(): void {
    this.newCancellations = [];
    this.newUnassignments = [];
    this.newFees = [];
  }

  private countLiveOffers(rideId: string, now: Date, excludeId?: string): number {
    let count = 0;
    for (const offer of this.offers.values()) {
      if (
        offer.rideId === rideId &&
        offer.id !== excludeId &&
        offer.status === 'PENDING' &&
        offer.expiresAt.getTime() > now.getTime()
      ) {
        count += 1;
      }
    }
    return count;
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
        ride.statusChangedAt = now;
        this.dirtyRideIds.add(ride.id);
        this.loseOpenOffers(ride.id);
        expired.push(ride.id);
      }
    }
    return expired.sort();
  }

  private expireIfDue(ride: RideRow, now: Date): void {
    if (ride.status === 'NEGOTIATING' && ride.expiresAt.getTime() <= now.getTime()) {
      ride.status = 'EXPIRED';
      ride.updatedAt = now;
      ride.statusChangedAt = now;
      this.dirtyRideIds.add(ride.id);
      this.loseOpenOffers(ride.id);
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
      vehicleClassCode: ride.vehicleClassCode,
      agreedFareVnd: ride.agreedFareVnd,
      discountVnd: ride.discountVnd,
      voucherCode: ride.voucherCode,
      voucherSponsor: ride.voucherSponsor,
      cancelledBy: ride.cancelledBy,
      assignedDriverId: ride.assignedDriverId,
      selectedOfferId: ride.selectedOfferId,
      expiresAt: new Date(ride.expiresAt),
      updatedAt: new Date(ride.updatedAt),
      createdAt: new Date(ride.createdAt),
      assignedAt: ride.assignedAt ? new Date(ride.assignedAt) : null,
      statusChangedAt: new Date(ride.statusChangedAt),
      noShow: ride.noShow,
      cancelReasonCode: ride.cancelReasonCode,
      priorFeesVnd: ride.priorFeesVnd,
      fareRaiseCount: ride.fareRaiseCount,
      autoAcceptOfferedFare: ride.autoAcceptOfferedFare,
      repostOfRideId: ride.repostOfRideId,
      stops: ride.stops.map((stop) => ({
        ...stop,
        arrivedAt: stop.arrivedAt ? new Date(stop.arrivedAt) : null,
        departedAt: stop.departedAt ? new Date(stop.departedAt) : null,
      })),
      routeVersion: ride.routeVersion,
      stopFeeVnd: ride.stopFeeVnd,
      stopWaitFreeMinutes: ride.stopWaitFreeMinutes,
      stopWaitFeeVndPerMinute: ride.stopWaitFeeVndPerMinute,
      waitFeeVnd: ride.waitFeeVnd,
      offers: offers.map((offer) => ({
        id: offer.id,
        driverId: offer.driverId,
        amountVnd: offer.amountVnd,
        kind: offer.kind,
        status: offer.status,
        expiresAt: new Date(offer.expiresAt),
        editCount: offer.editCount,
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
  vehicleClassCode?: string;
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
  assignedAt?: Date | null;
  statusChangedAt?: Date | null;
  noShow?: boolean;
  cancelReasonCode?: string | null;
  priorFeesVnd?: number;
  fareRaiseCount?: number;
  autoAcceptOfferedFare?: boolean;
  repostOfRideId?: string | null;
  stops?: RideStopSnapshot[];
  routeVersion?: number;
  stopFeeVnd?: number;
  stopWaitFreeMinutes?: number;
  stopWaitFeeVndPerMinute?: number;
  waitFeeVnd?: number;
}): RideRow {
  return {
    ...input,
    stops: [...(input.stops ?? [])].sort((a, b) => a.seq - b.seq).map((stop) => ({
      seq: stop.seq,
      lat: stop.lat,
      lng: stop.lng,
      label: stop.label,
      arrivedAt: stop.arrivedAt ?? null,
      departedAt: stop.departedAt ?? null,
    })),
    routeVersion: input.routeVersion ?? 0,
    stopFeeVnd: input.stopFeeVnd ?? 0,
    stopWaitFreeMinutes: input.stopWaitFreeMinutes ?? 0,
    stopWaitFeeVndPerMinute: input.stopWaitFeeVndPerMinute ?? 0,
    waitFeeVnd: input.waitFeeVnd ?? 0,
    fareRaiseCount: input.fareRaiseCount ?? 0,
    autoAcceptOfferedFare: input.autoAcceptOfferedFare ?? false,
    repostOfRideId: input.repostOfRideId ?? null,
    assignedAt: input.assignedAt ?? null,
    statusChangedAt: input.statusChangedAt ?? input.updatedAt,
    noShow: input.noShow ?? false,
    cancelReasonCode: input.cancelReasonCode ?? null,
    priorFeesVnd: input.priorFeesVnd ?? 0,
    // Legacy hydrate only: Prisma @default and pre-Wave-1 rows may omit class.
    vehicleClassCode: input.vehicleClassCode ?? 'MOTORBIKE',
    discountVnd: input.discountVnd ?? 0,
    voucherCode: input.voucherCode ?? null,
    voucherSponsor: input.voucherSponsor ?? null,
    cancelledBy: input.cancelledBy ?? null,
    loadedStatus: input.status,
  };
}

export type { OfferRow, RideRow, SelectionRow };

/**
 * Wait fee for a multi-stop ride: per stop, whole minutes between arrival and departure beyond
 * the free minutes, times the per-minute fee. 0 for single-destination rides.
 */
export function stopWaitFeeVnd(
  stops: ReadonlyArray<Pick<RideStopSnapshot, 'arrivedAt' | 'departedAt'>>,
  freeMinutes: number,
  feePerMinuteVnd: number,
): number {
  if (feePerMinuteVnd <= 0) return 0;
  let total = 0;
  for (const stop of stops) {
    if (!stop.arrivedAt || !stop.departedAt) continue;
    const waited = Math.floor((stop.departedAt.getTime() - stop.arrivedAt.getTime()) / 60_000);
    total += Math.max(0, waited - Math.max(0, freeMinutes)) * feePerMinuteVnd;
  }
  return total;
}

/** Oldest live ACCEPT at the customer's current price, when auto-accept is on. */
export function exactPendingAccept(
  ride: Pick<RideSnapshot, 'status' | 'offeredFareVnd' | 'autoAcceptOfferedFare' | 'offers'>,
  now: Date,
): RideOfferSnapshot | null {
  if (ride.autoAcceptOfferedFare !== true || ride.status !== 'NEGOTIATING') {
    return null;
  }
  return (
    ride.offers.find(
      (offer) =>
        offer.status === 'PENDING' &&
        offer.kind === 'ACCEPT' &&
        offer.amountVnd === ride.offeredFareVnd &&
        offer.expiresAt.getTime() > now.getTime(),
    ) ?? null
  );
}
