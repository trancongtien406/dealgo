import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Subject, type Observable } from 'rxjs';

export type RideOfferChangeReason =
  | 'OFFER'
  | 'SELECTED'
  | 'CANCELLED'
  | 'EXPIRED'
  | 'REASSIGNED'
  // Request lifecycle reasons. CREATED/RAISED/REASSIGNED/DRIVER_CANCELLED/TIMEOUT also
  // fan the request out to nearby online drivers.
  | 'CREATED'
  | 'RAISED'
  | 'DECLINED'
  | 'WITHDRAWN'
  | 'DRIVER_CANCELLED'
  | 'TIMEOUT'
  // Customer edited the stops while negotiating: pending offers died, a new round starts.
  | 'ROUTE_CHANGED'
  // t71u: one driver's offer reached its expiresAt (RIDE_OFFER_TTL_SECONDS, default 20s).
  | 'OFFER_EXPIRED'
  // A driver opened or left the request. Customer reload only; not a new dispatch.
  | 'VIEWERS';

/** Reasons after which a NEGOTIATING ride should be (re)announced to nearby drivers. */
export const RIDE_REQUEST_BROADCAST_REASONS: ReadonlySet<RideOfferChangeReason> = new Set([
  'CREATED',
  'RAISED',
  'REASSIGNED',
  'DRIVER_CANCELLED',
  'TIMEOUT',
  'ROUTE_CHANGED',
]);

/** Something changed in a ride's offer list (post-commit, in-process). */
export type RideOfferChange = { rideId: string; reason: RideOfferChangeReason; at: Date };

/**
 * In-process bus: RideService publishes after an offer/counter, selection, cancel or expiry
 * commits; RealtimeModule pushes `rideOffers` to the customer-only `ride-offers:{id}` room.
 * Cross-instance delivery rides on the Socket.IO Redis adapter.
 */
@Injectable()
export class RideOfferEvents implements OnModuleDestroy {
  private readonly subject = new Subject<RideOfferChange>();

  get changes(): Observable<RideOfferChange> {
    return this.subject.asObservable();
  }

  publish(change: RideOfferChange): void {
    this.subject.next(change);
  }

  onModuleDestroy(): void {
    this.subject.complete();
  }
}
