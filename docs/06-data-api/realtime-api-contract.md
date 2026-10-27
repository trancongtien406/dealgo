---
doc_id: DG-API-RT-001
title: "DealGo — Realtime (Socket.IO) API contract"
version: "1.0.0"
status: "CURRENT"
owner: "Backend"
last_updated: "2026-10-26"
related:
  - ADR-003
  - docs/06-data-api/rest-api.openapi.yaml
  - docs/09-operations/push/push-notifications.md
---

# Realtime API contract

The realtime channel carries **hints and live positions**. PostgreSQL and the REST API are always the source of truth: when a client gets a `snapshot` hint (or reconnects) it re-reads the aggregate with one REST `GET`. Rides stay inDrive-style. The server pushes the request to nearby drivers and pushes offers to the customer. It never auto-matches a driver.

Source: `backend/src/modules/communication/realtime/*`, `backend/src/modules/communication/outbox/outbox-relay.service.ts`.

## Transport

| Item | Value |
|---|---|
| Protocol | Socket.IO, default namespace `/` (`SnapshotGateway`) |
| Auth | Access JWT in `handshake.auth.token` (`Bearer <jwt>` or the raw JWT) or in the `Authorization: Bearer <jwt>` header. A bad or missing token gets `error {code:'UNAUTHORIZED'}` and the server disconnects. |
| Session audit | Every 30 s the gateway re-checks each socket's session. A revoked session (logout, password change, account deletion, "sign out other devices") gets `error {code:'UNAUTHORIZED'}` and is disconnected. |
| Private room | On connect every socket joins `user:{userId}` automatically. Clients cannot subscribe to `user:` rooms. |
| Multi-instance | `@socket.io/redis-adapter` when `REDIS_URL` is reachable. If Redis is down it falls back to the in-memory adapter (single instance only). |
| Event source | Status hints come from the transactional outbox (`OUTBOX_RELAY_INTERVAL_MS`, default 2 s). Location, route and offer events are emitted in-process right after the write commits. |

## Client → server

### `subscribe`

```json
{ "room": "ride:<uuid>" }
```

Ack:

```json
{ "ok": true, "room": "ride:<uuid>" }
{ "ok": false, "code": "UNAUTHORIZED" | "INVALID_ROOM" | "FORBIDDEN" }
```

### `unsubscribe`

`{ "room": "<room>" }`. Leaves the room. The ack has the same shape.

### Rooms and who may join

| Room | Who may join (checked on every `subscribe`) | Events |
|---|---|---|
| `ride:{rideId}` | The ride's customer. The assigned driver while the ride is assigned or in progress. While `NEGOTIATING`, any driver with an active DRIVER grant whose approved vehicle class equals the ride's class. | `snapshot`, `routeUpdated` |
| `ride-offers:{rideId}` | The ride's customer only | `rideOffers` |
| `ride-location:{rideId}` | The ride's customer only | `driverLocation` |
| `food:{orderId}` | The customer (active CUSTOMER grant). The store owner (active MERCHANT grant). Any active driver while the order is `READY`. The assigned driver while `ASSIGNED`, `PICKED_UP`, `DELIVERED` or `FAILED`. | `snapshot`, `routeUpdated` |
| `food-location:{orderId}` | The order's customer only | `driverLocation` |
| `store:{storeId}` | The store owner with an active MERCHANT grant (kitchen board) | `snapshot` for every order of the store |
| `user:{userId}` | Joined automatically at connect | `snapshot` (driver job assigned), `rideRequest`, `partnerStatus`, `call`, `chatMessage` |

Room ids must be UUIDs. Anything else gets `INVALID_ROOM`. When a ride leaves `NEGOTIATING`, the server first removes from `ride:{id}` every socket that may no longer read it (losing bidders), then emits the snapshot.

## Server → client events

### `snapshot`

```json
{
  "eventType": "Ride.status.changed",
  "aggregateType": "Ride" | "FoodOrder",
  "aggregateId": "<uuid>",
  "status": "ASSIGNED",
  "revision": "<outbox eventKey>",
  "occurredAt": "2026-10-26T08:00:00.000Z",
  "storeId": "<uuid, FoodOrder only>"
}
```

- Sent to `ride:{id}` or `food:{id}`. A FoodOrder snapshot is also sent to `store:{storeId}`.
- When a ride or food order becomes `ASSIGNED`, the same payload also goes to the assigned driver's `user:{driverId}` room. The driver app then opens the job from any screen without polling.
- The payload carries no PII and no money. Clients must re-read the aggregate via REST.

### `rideOffers` (customer, room `ride-offers:{rideId}`)

```json
{
  "rideId": "<uuid>",
  "reason": "OFFER",
  "status": "NEGOTIATING",
  "offers": [
    { "id": "<uuid>", "driverId": "<uuid>", "amountVnd": 45000, "kind": "ACCEPT" | "COUNTER",
      "status": "PENDING" | "SELECTED" | "LOST" | "DECLINED" | "WITHDRAWN",
      "expiresAt": "…", "editCount": 1 }
  ],
  "revision": "<ride updatedAt>",
  "at": "…"
}
```

`reason` is one of `CREATED`, `OFFER`, `RAISED`, `DECLINED`, `WITHDRAWN`, `SELECTED`, `CANCELLED`, `EXPIRED`, `TIMEOUT`, `REASSIGNED`, `DRIVER_CANCELLED`. The `offers` array is the full current list, so the client replaces its list rather than merging. When an `OFFER` change leaves exactly one pending offer, the customer also gets a push ("first offer received") that opens `/customer/ride/offers/{rideId}`.

### `rideRequest` (drivers, room `user:{driverId}`)

```json
{ "reason": "CREATED", "ride": { /* OpenRideView */ }, "at": "…" }
```

- Emitted on `CREATED`, `RAISED`, `REASSIGNED`, `DRIVER_CANCELLED` and `TIMEOUT`.
- It goes to every online driver whose approved class matches the ride and whose fresh fix is within `DRIVER_SEARCH_RADIUS_KM` of pickup. The admin settings `DISPATCH_REQUIRE_FRESH_PRESENCE` and `DRIVER_DEBT_LIMIT_VND` decide eligibility.
- `ride` is the same `OpenRideView` as `GET /v1/rides/open`: pickup and drop-off labels, offered and reference fare, class, expiry, offer count, the customer's rating summary and the pickup distance. It never carries the customer id.
- The same change also sends a high-priority FCM push to drivers whose app may be in the background. The push is only sent while `RIDE_REQUEST_PUSH_ENABLED` is on and goes to at most `RIDE_REQUEST_PUSH_MAX_DRIVERS` drivers, nearest first. Each driver gets at most one push per ride per minute. The push collapses per ride, expires with the request and respects the driver's RIDE notification preference. It plays the spoken "DealGo, có cuốc mới" sound (see [push notifications › New job sounds](../09-operations/push/push-notifications.md#new-job-sounds)).

### `driverLocation` (customer, rooms `ride-location:` / `food-location:`)

```json
{ "aggregateType": "Ride" | "FoodOrder", "aggregateId": "<uuid>", "lat": 10.77, "lng": 106.70,
  "at": "…", "heading": 90, "speedMps": 8.2 }
```

- Fed by `POST /v1/me/presence/location` from the assigned driver, while the ride is assigned or in progress, or the order is `ASSIGNED` or `PICKED_UP`.
- Fan-out is throttled to at most one emit per driver every 2 s.
- The same position is available by REST: `GET /v1/rides/{id}/driver-location` and `GET /v1/food/orders/{id}/driver-location`.

Server-side acceptance of a fix:

| Policy | ON_TRIP (has a live job) | IDLE (online, no job) | Env |
|---|---|---|---|
| Send interval | 5 s | 15 s | `DRIVER_LOCATION_ON_TRIP_INTERVAL_MS`, `DRIVER_LOCATION_IDLE_INTERVAL_MS` |
| Min movement | 10 m | 50 m | `DRIVER_LOCATION_*_MIN_DISTANCE_M` |
| Keep-alive while still | 30 s | 60 s | `DRIVER_LOCATION_MAX_SILENCE_MS` (idle = 2×) |
| Min gap between accepted fixes | 1 s | 1 s | `DRIVER_LOCATION_MIN_ACCEPT_INTERVAL_MS` |

The server rejects a fix with one of these reasons: `RATE_LIMITED`, `STALE`, `FUTURE`, `OUT_OF_ORDER`, `LOW_ACCURACY`, `IMPLAUSIBLE_JUMP`.

### `routeUpdated` (rooms `ride:` / `food:`)

```json
{
  "aggregateType": "Ride" | "FoodOrder", "aggregateId": "<uuid>",
  "phase": "APPROACH" | "TRIP",
  "reason": "INITIAL" | "OFF_ROUTE",
  "route": { "available": true, "provider": "mapbox", "coords": [[lat, lng], …], "distanceM": 3200, "durationSec": 540 },
  "at": "…"
}
```

- `APPROACH` is driver → pickup (or store). `TRIP` is pickup → drop-off.
- The server keeps one route per job and phase in memory (`PhaseRouteCache`, per backend instance, 4 h TTL). `GET` of a ride or food order reads the approach leg from that cache; it calls Directions only when the cache has no leg for the phase yet.
- A new route is computed only at the start of a phase (`INITIAL`) and when the driver is farther than `ROUTE_OFF_ROUTE_THRESHOLD_M` (default 150 m) from the cached route, at most once per `ROUTE_REROUTE_MIN_INTERVAL_SECONDS` (default 120 s) per job (`OFF_ROUTE`). There is no periodic refresh. Both values are admin settings.
- The app does no turn-by-turn guidance. The driver taps one "Điều hướng" button, which opens a bottom sheet listing the installed apps (Google Maps, Apple Maps on iOS only, Waze) plus Google Maps web as the always-available fallback; the destination follows the phase (pickup, merchant or drop-off). The customer's ETA is the cached route's `durationSec` scaled by the share of the route still ahead of the latest `driverLocation`, so it moves without any extra routing request.
- With `ROUTING_PROVIDER` unset the event carries `available:false`. The app then draws no road line; the Admin map draws a straight dashed line.

### `chatMessage` (rooms `user:{customerId}`, `user:{driverId}`)

```json
{ "aggregateType": "Ride" | "FoodOrder", "aggregateId": "<uuid>",
  "message": { "id": "<uuid>", "threadId": "<uuid>", "senderUserId": "<uuid>",
               "body": "…", "createdAt": "…" } }
```

Sent when a ride or food-order chat message is stored, including the server's missed-call note (body starts with `📞`). It goes only to the private rooms of the customer and the assigned driver (and the sender), never to the `ride:` / `food:` rooms, which bidding drivers and the store may join. The app merges it by `message.id`, so a replay or a reconnect reload never shows a message twice. There are no delivered/read receipts.

### `partnerStatus` (room `user:{userId}`)

```json
{ "applicationId": "<uuid>", "userId": "<uuid>", "role": "DRIVER" | "MERCHANT",
  "status": "APPROVED" | "REJECTED" | "SUBMITTED", "occurredAt": "…" }
```

Sent when Ops approves or rejects a KYC/KYB application. A push plus an inbox row ("Hồ sơ đã được duyệt / bị từ chối") go out at the same time.

### `call` (rooms `user:{callerUserId}` and `user:{calleeUserId}`)

```json
{ "callId": "<uuid>", "aggregateType": "Ride" | "FoodOrder", "aggregateId": "<uuid>",
  "status": "RINGING" | "ACCEPTED" | "DECLINED" | "MISSED" | "ENDED",
  "callerUserId": "<uuid>", "calleeUserId": "<uuid>", "callerRole": "CUSTOMER" | "DRIVER",
  "ringUntil": "…", "endReason": "NO_ANSWER" | "CANCELLED" | "HANGUP" | "STALE" | null,
  "occurredAt": "…" }
```

In-app voice call between the customer and the assigned driver (`DEC-PROD-064`). Sent to both parties on every state change: `RINGING` when the caller starts (`POST /v1/rides/:id/calls` or `POST /v1/food/orders/:id/calls`), then `ACCEPTED` / `DECLINED` / `MISSED` / `ENDED`. The callee rings on `RINGING` until `ringUntil`; both apps close the call screen on a terminal status. A callee already in another call declines automatically. The payload carries no media token: the caller gets its LiveKit token from the start response and the callee from `POST /v1/calls/:id/accept`. A `Call.incoming` push goes out with `RINGING` for an app in the background, and `Call.missed` when the call ends unanswered. After a reconnect the app re-reads `GET /v1/calls/:id` for the call it holds.

### `error`

`{ "code": "UNAUTHORIZED" }` is sent before a server-side disconnect (bad token or revoked session). The client must refresh its session once and reconnect. Socket.IO does not auto-retry a server-side disconnect.

## Client rules

1. On every (re)connect, read the latest access token, re-subscribe the rooms you hold, and issue one REST `GET` per open screen. Events missed while offline are not replayed.
2. Treat `snapshot` as "something changed" only. Never derive money, codes or PII from it.
3. `rideOffers.offers` replaces the local list.
4. Chat: the sheet loads `GET /v1/rides/:id/messages` or `GET /v1/food/orders/:id/messages` page 1 (the newest 50, oldest first) on open and after a reconnect, then follows `chatMessage`. A new message also sends a push to the other party (at most one per thread per recipient per minute; the text is never in the push). The unread badge on the chat button counts `chatMessage` events from the other party while the sheet is closed; it is in memory only.

## Client usage today

| Client | Events used |
|---|---|
| Mobile (`mobile/lib/core/realtime/socket_snapshot_realtime.dart`) | `snapshot`, `driverLocation`, `rideOffers`, `routeUpdated`, `partnerStatus`, `call` (global `VoiceCallCubit`), `chatMessage` (chat sheet and unread badge). The driver job board loads `GET /v1/rides/open` and `GET /v1/food/orders/ready` when it opens and when duty or services change. It does not listen to `rideRequest`; background drivers are reached by the request push. The merchant order board also refreshes every 10 s. |
| Admin web | Uses no socket. The live board and lists poll REST (`/v1/ops/monitor/snapshot`). |
