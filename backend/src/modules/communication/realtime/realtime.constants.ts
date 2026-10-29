export const SNAPSHOT_EVENT = 'snapshot';

export const SUBSCRIBE_EVENT = 'subscribe';

export const UNSUBSCRIBE_EVENT = 'unsubscribe';

/** Live driver GPS push (DEC-PROD-031 realtime); customer-only rooms. */
export const DRIVER_LOCATION_EVENT = 'driverLocation';

/** Offer list changed (bid/offer, DEC-PROD-031 rev 2026-10-24); customer-only room. */
export const RIDE_OFFERS_EVENT = 'rideOffers';

/**
 * A NEGOTIATING ride request pushed to each nearby online driver's private
 * `user:{id}` room (created / fare raised / back to bidding). The payload is the same
 * shape as one `GET /v1/rides/open` item, so the app can insert it without refetching.
 * REST `GET /v1/rides/open` remains the snapshot on (re)connect.
 */
export const RIDE_REQUEST_EVENT = 'rideRequest';

/** To nearby online food drivers' private rooms: a READY food order needs a driver (refresh the feed). */
export const FOOD_REQUEST_EVENT = 'foodRequest';

export type FoodRequestEventPayload = {
  orderId: string;
  at: string;
};

/**
 * To the dropped driver's private room: they lost an assigned ride (start/approach timeout,
 * own drop or ops reassign). The driver app clears the active job and shows `reasonCode`.
 */
export const RIDE_UNASSIGNED_EVENT_NAME = 'rideUnassigned';

export type RideUnassignedEventPayload = {
  rideId: string;
  reasonCode: string;
  actor: string;
  fromStatus: string;
  occurredAt: string;
};

export type RideRequestEventPayload = {
  reason: string;
  ride: Record<string, unknown> & { id: string };
  at: string;
};

export type SnapshotRoomKind =
  | 'ride'
  | 'food'
  | 'store'
  | 'ride-location'
  | 'food-location'
  | 'ride-offers';

export type ParsedSnapshotRoom = {
  kind: SnapshotRoomKind;
  id: string;
  room: string;
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseSnapshotRoom(raw: string | undefined | null): ParsedSnapshotRoom | null {
  if (!raw || typeof raw !== 'string') {
    return null;
  }
  const trimmed = raw.trim();
  const match = /^(ride-location|food-location|ride-offers|ride|food|store):(.+)$/.exec(trimmed);
  if (!match) {
    return null;
  }
  const kind = match[1] as SnapshotRoomKind;
  const id = match[2]?.trim() ?? '';
  if (!UUID_RE.test(id)) {
    return null;
  }
  return { kind, id, room: `${kind}:${id}` };
}

export function roomForAggregate(
  aggregateType: string,
  aggregateId: string,
): string | null {
  if (aggregateType === 'Ride') {
    return `ride:${aggregateId}`;
  }
  if (aggregateType === 'FoodOrder') {
    return `food:${aggregateId}`;
  }
  return null;
}

/** Merchant kitchen board listens on store:{storeId} (DEC-PROD-041). */
export function roomForStore(storeId: string): string {
  return `store:${storeId}`;
}

export type SnapshotEventPayload = {
  eventType: string;
  aggregateType: string;
  aggregateId: string;
  status: string;
  revision: string;
  occurredAt: string;
  /** Present on FoodOrder events so fan-out can also hit the store room. */
  storeId?: string;
};

/**
 * Live location rooms are separate from `ride:` / `food:` because those admit offering
 * drivers / merchants and are not re-checked after assignment; GPS is customer-only.
 */
export function roomForDriverLocation(kind: 'ride' | 'food', id: string): string {
  return `${kind}-location:${id}`;
}

/** Phase-aware road leg (approach driver→pickup, or trip) to `ride:`/`food:` rooms (driver + customer). */
export const ROUTE_UPDATED_EVENT = 'routeUpdated';

export type RouteUpdatedEventPayload = {
  aggregateType: 'Ride' | 'FoodOrder';
  aggregateId: string;
  phase: 'APPROACH' | 'TRIP';
  /** INITIAL = first leg of this phase, OFF_ROUTE = throttled deviation re-route (no periodic refresh). */
  reason: 'INITIAL' | 'OFF_ROUTE';
  route: {
    available: boolean;
    provider: string;
    coords: [number, number][];
    distanceM: number | null;
    durationSec: number | null;
  };
  at: string;
};

export type DriverLocationEventPayload = {
  aggregateType: 'Ride' | 'FoodOrder';
  aggregateId: string;
  lat: number;
  lng: number;
  at: string;
  heading?: number;
  speedMps?: number;
};

/** Customer-only offers room: `ride:` admits same-class drivers, so offers never go there. */
export function roomForRideOffers(rideId: string): string {
  return `ride-offers:${rideId}`;
}

export type RideOffersEventPayload = {
  rideId: string;
  reason: string;
  status: string;
  offers: Array<{
    id: string;
    driverId: string;
    amountVnd: number;
    kind: 'ACCEPT' | 'COUNTER';
    status: 'PENDING' | 'SELECTED' | 'LOST' | 'DECLINED' | 'WITHDRAWN';
    expiresAt: string;
    editCount?: number;
  }>;
  /** Ride updatedAt; clients drop payloads older than what they already show. */
  revision: string;
  at: string;
};

/**
 * Partner application decided by ops (approve/reject). Sent to the applicant's private
 * `user:{userId}` room, which every authenticated socket joins on connect; the status
 * page then refetches over REST. No polling.
 */
export const PARTNER_STATUS_EVENT = 'partnerStatus';

export function roomForUser(userId: string): string {
  return `user:${userId}`;
}

export type PartnerStatusEventPayload = {
  applicationId: string;
  userId: string;
  role: string;
  status: string;
  occurredAt: string;
};

/**
 * `call` push on both parties' private `user:` rooms (in-app voice call, DEC-PROD-007).
 * Sent on every state change; the app rings on RINGING for the callee and closes the call
 * screen on DECLINED / MISSED / ENDED. REST `GET /v1/calls/:callId` is the source of truth.
 */
export const CALL_EVENT = 'call';

export type CallEventPayload = {
  callId: string;
  aggregateType: 'Ride' | 'FoodOrder';
  aggregateId: string;
  status: 'RINGING' | 'ACCEPTED' | 'DECLINED' | 'MISSED' | 'ENDED';
  callerUserId: string;
  calleeUserId: string;
  /** Role of the caller in this trip: CUSTOMER or DRIVER. */
  callerRole: 'CUSTOMER' | 'DRIVER';
  ringUntil: string;
  endReason: string | null;
  occurredAt: string;
};

/**
 * `chatMessage` push on both participants' private `user:` rooms (transaction chat).
 * Carries the full message so an open chat appends it without a GET (dedupe by `id`);
 * a closed chat only bumps its unread badge. Never sent to `ride:`/`food:` rooms, which
 * admit offering drivers / the merchant. REST `GET …/messages` is the snapshot on open and
 * after a reconnect.
 */
export const CHAT_MESSAGE_EVENT = 'chatMessage';

/**
 * To each recipient's private room when an inbox row is written. The app bumps
 * its unread badge; `GET /v1/me/notifications` stays the count snapshot.
 */
export const INBOX_EVENT = 'inbox';

export type InboxEventPayload = {
  category: string;
  at: string;
};

export type ChatMessageEventPayload = {
  /** FoodOrder = customer↔driver thread; FoodOrderShop = customer↔shop thread. */
  aggregateType: 'Ride' | 'FoodOrder' | 'FoodOrderShop';
  aggregateId: string;
  message: {
    id: string;
    threadId: string;
    senderUserId: string;
    body: string;
    createdAt: string;
  };
};
