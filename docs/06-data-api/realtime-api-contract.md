---
doc_id: DG-API-RT-001
title: "DealGo — Realtime (Socket.IO) API contract"
version: "0.1.0"
status: "DRAFT"
owner: "Backend"
last_updated: "2026-10-14"
related:
  - ADR-003
  - docs/06-data-api/rest-api.openapi.yaml
---

# Realtime API contract (DRAFT)

> **Phase F partial.** Socket.IO emits status *hints* only. PostgreSQL + REST GET remain the source of truth. Push mock + chat stub are separate HTTP/outbox paths. Do not treat this document as Phase 7 Done (real FCM / voice still missing).

## Transport

| Item | Value |
|---|---|
| Protocol | Socket.IO (Nest `@WebSocketGateway`, default namespace `/`) |
| Auth | Access JWT — `handshake.auth.token` (`Bearer <jwt>` or raw JWT) **or** `Authorization: Bearer <jwt>` header |
| Multi-instance | Optional `@socket.io/redis-adapter` when `REDIS_URL` is reachable; soft fallback to in-memory adapter |
| Push | Outbox relay → push mock to known participants (`PUSH_PROVIDER=mock`; production refuses mock) |
| Chat / real FCM / voice | Chat is REST stub; real FCM + voice out of scope |

## Client → server

### `subscribe`

```json
{ "room": "ride:<uuid>" }
```

or

```json
{ "room": "food:<uuid>" }
```

Ack:

- `{ "ok": true, "room": "ride:<uuid>" }` when the actor is a participant (same rules as REST GET)
- `{ "ok": false, "code": "FORBIDDEN" | "INVALID_ROOM" | "UNAUTHORIZED" }` otherwise

### `unsubscribe`

```json
{ "room": "ride:<uuid>" }
```

Leaves the room if joined. Does not require re-authz beyond a valid connection.

## Server → client

### Event `snapshot`

Emitted to room `ride:{id}` / `food:{id}` after the outbox relay marks a status row processed.

```json
{
  "eventType": "Ride.status.ASSIGNED",
  "aggregateType": "Ride",
  "aggregateId": "<uuid>",
  "status": "ASSIGNED",
  "revision": "Ride:<uuid>:status:ASSIGNED",
  "occurredAt": "2026-10-14T00:01:00.000Z"
}
```

| Field | Notes |
|---|---|
| `revision` | Currently the outbox `eventKey` (idempotent key). Not a monotonic integer sequence yet. |
| `occurredAt` | Relay processing time (ISO-8601). Prefer entity `updatedAt` from REST on reconcile. |

## AuthZ

Join is allowed only when `RideService.canSubscribe` / `FoodService.canSubscribe` would allow the same actor to read the entity via REST (customer / assigned driver / merchant owner / negotiating-driver visibility rules). Knowing an id is not enough (`AUTH-TC-024`).

Ops HTTP explorers do **not** grant socket room access in this skeleton.

## Reconnect policy (mandatory)

1. Re-authenticate the socket.
2. Re-`subscribe` needed rooms.
3. **GET** the ride/order from REST and reconcile by status/revision — do not trust the last `snapshot` alone.
4. Offline / dropped socket must not auto-cancel or auto-complete.

## Remaining gaps (not Done)

- Redis Socket.IO adapter for multi-instance
- FCM / push mock consumer
- Chat / voice channels
- Monotonic revision / sequence per aggregate
- Flutter socket client
- Full presence / driver location fan-out
