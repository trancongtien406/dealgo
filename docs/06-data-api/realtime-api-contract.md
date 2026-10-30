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
| `user:{userId}` | Joined automatically at connect | `snapshot` (driver job assigned), `rideRequest`, `partnerStatus`, `paymentStatus`, `call`, `chatMessage` |

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
- When the request leaves NEGOTIATING (customer cancelled, picked a driver, expired) every alerted driver gets `{ reason: "CLOSED_<reason>", ride: { id, status: "CLOSED" } }` so the app re-syncs the feed and drops the incoming-job card. Clients re-fetch `GET /v1/rides/open`; they never poll.
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

### `paymentStatus` (room `user:{customerId}`, since t50u)

```json
{ "entityType": "RIDE" | "FOOD_ORDER", "entityId": "<uuid>", "intentId": "<uuid>",
  "status": "PAID" | "FAILED" | "EXPIRED" | "REFUND_PENDING" | "REFUNDED" | "PENDING", "occurredAt": "…" }
```

Sent to the job's customer when a checkout intent changes state: a verified PSP IPN (captured or failed), API-process reconcile (captured, failed, expired) or a refund. Replays, bad signatures and amount mismatches emit nothing. It is a hint only: the payment page re-GETs `GET /v1/payments/checkout` status, which stays the source of truth. Source: `PaymentStatusBus` (payment module) → `PaymentStatusBridgeService` (realtime module). Limitation: if reconcile runs in the worker process, which has no bound socket server, no hint is sent; the app still re-GETs on open, on socket reconnect and on app resume.

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
| Mobile (`mobile/lib/core/realtime/socket_snapshot_realtime.dart`) | `snapshot`, `driverLocation`, `rideOffers`, `routeUpdated`, `partnerStatus`, `paymentStatus`, `call` (global `VoiceCallCubit`), `chatMessage` (chat sheet and unread badge). The driver job board loads `GET /v1/rides/open` and `GET /v1/food/orders/ready` when it opens and when duty or services change. It does not listen to `rideRequest`; background drivers are reached by the request push. `rideRequest`/`foodRequest` drive the full-screen incoming-job card and feed re-sync. Since t50u the app has **no periodic REST polling** for realtime data: merchant queue/order, driver job resumer and incoming-job card reload only on open, a socket hint, socket reconnect or app resume. Remaining UI timers are local only (countdowns, ring/vibrate, banner carousel, GPS reporter, local GPS preview). The payment status page also no longer polls: it re-GETs on open, resume, reconnect (while not terminal) and on a `paymentStatus` hint for its job. |
| Admin web | No socket client (the gateway is bearer-only). Live via **SSE** instead (owner, 2026-10-30: "Làm luôn realtime cho admin bằng SSE"): `AdminNav` opens one `EventSource('/api/ops/events')`; the BFF relays Nest `GET /v1/ops/events` with the ops cookie session. `monitor` / `systemErrors` hints invalidate the React Query REST snapshots; after a reconnect both are refetched. The 30 s monitor and 120 s system-errors polling are removed. See "Admin SSE (ops events)" below. |

## Admin SSE (ops events)

- **Endpoint:** `GET /v1/ops/events` (`text/event-stream`), `OpsSessionGuard` like `/v1/ops/monitor/snapshot`. Browser path: `/api/ops/events` (Next BFF, cookie session, bearer added server-side; the Nest JWT never reaches the browser).
- **Events** (payload `{type, reason, at, aggregateType?, count?}`; hints only, REST is the source of truth):
  - `ready`: `{systemErrors: boolean}` sent first.
  - `monitor`: a ride/food snapshot or partner status was emitted; coalesced to at most one per 2 s per stream.
  - `systemErrors`: an issue status changed (`statusChanged`) or the unresolved count changed (`countChanged`). Only sent to actors with `errors.read` (same rule as `OpsPermissionGuard`).
- **Heartbeat:** comment `: ping <ms>` every 25 s; `retry: 5000`. The server clears the heartbeat, the coalesce timer and the bus subscription on close.
- **Sources:** `OpsEventBus` (in-process). The worker's outbox relay emits through `SnapshotFanoutService.signalOps`, which also calls Socket.IO `serverSideEmit` on the existing Redis adapter so API nodes receive worker hints. Without `REDIS_URL` the worker cannot reach the API (same limit as socket snapshots).
- **Sentry:** no webhook (it would need a Sentry integration client secret). While at least one stream is open, the API checks `unresolvedCount()` every 120 s and emits only on change; the browser no longer polls.
- **Client:** first open does nothing (initial data comes from REST); a reopen after an error refetches monitor + system errors. If the browser gives up (non-2xx, e.g. 401) the client recreates the stream with backoff 5 s → 60 s. Unmount closes the stream and clears any retry timer.

## Pricing is not realtime (t50u)

The ride quote (`POST /v1/rides/quote`) is a server REST snapshot: zone resolved from pickup, per-zone tariff or global class default, and the bid band (`RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE` / `RIDE_BID_CEILING_PERCENT_OF_REFERENCE`). There is no tariff socket event. On create the tariff and band are written once to `ride_pricing_snapshots`; raises, counters and stop edits use that snapshot.

## KYC/KYB manual review (t52u)

- **Event:** `partnerStatus` on room `user:{userId}` (same payload as above). `status` can now also be `IN_REVIEW`, sent when an ops reviewer claims the case (`POST /v1/ops/partner-applications/:id/claim`). `APPROVED` / `REJECTED` still come only from a human reviewer; the optional AI pre-check never emits a status.
- **Source:** the transactional outbox (`PartnerApplication.status.<STATUS>`) written with the status change and the `ops_audit_logs` row, relayed by the worker. Push/inbox copy is sent only for `APPROVED` / `REJECTED`.
- **Client:** hint only. The app re-GETs `GET /v1/me/partner-applications`; `IN_REVIEW` shows as "pending". Resubmitting while `IN_REVIEW` returns 409.

## Parcel delivery (t58u, DEC-PROD-071 DRAFT)

A parcel job is a Ride with `serviceKind: "PARCEL"`, so it uses the **same rooms and events**; there are no new events.

- `rideRequest` / `GET /v1/rides/open`: the `OpenRideView` gains `serviceKind` (`RIDE` | `PARCEL`) and `parcel` (`{ sizeClass, weightKg, note, payer, surchargeVnd }` or `null`). Parcel jobs only reach drivers whose presence has `parcelEnabled: true`; ride jobs keep the existing eligibility. Sender/recipient phones are never in the feed.
- `rideOffers`, `driverLocation`, `routeUpdated`, `chatMessage`: unchanged.
- Status changes reuse the ride status events: `IN_TRIP` after `POST /v1/parcels/:id/pickup`, `COMPLETED` after `deliver` or `returned`. A failed delivery emits the ride status `IN_TRIP` with the outbox hint suffix `parcel:RETURNING`; clients re-fetch `GET /v1/parcels/:id` for the parcel outcome (`PENDING | DELIVERED | RETURNING | RETURNED`; pickup sets `pickedUpAt`). Clients never poll.
