import { Injectable, Logger } from '@nestjs/common';
import type { Server } from 'socket.io';
import {
  DRIVER_LOCATION_EVENT,
  roomForAggregate,
  roomForDriverLocation,
  type DriverLocationEventPayload,
  RIDE_OFFERS_EVENT,
  RIDE_REQUEST_EVENT,
  FOOD_REQUEST_EVENT,
  type FoodRequestEventPayload,
  RIDE_UNASSIGNED_EVENT_NAME,
  type RideUnassignedEventPayload,
  type RideRequestEventPayload,
  ROUTE_UPDATED_EVENT,
  type RouteUpdatedEventPayload,
  roomForRideOffers,
  type RideOffersEventPayload,
  roomForStore,
  roomForUser,
  PARTNER_STATUS_EVENT,
  CALL_EVENT,
  type CallEventPayload,
  CHAT_MESSAGE_EVENT,
  type ChatMessageEventPayload,
  INBOX_EVENT,
  type InboxEventPayload,
  type PartnerStatusEventPayload,
  SNAPSHOT_EVENT,
  type SnapshotEventPayload,
  type ParsedSnapshotRoom,
} from './realtime.constants.js';

export type RoomAccessCheck = (userId: string, room: ParsedSnapshotRoom) => Promise<boolean>;

/**
 * Thin fan-out for status snapshots. Postgres remains source of truth;
 * missing server (tests / pre-listen) is a silent no-op.
 * FoodOrder events also emit to store:{storeId} when storeId is set (merchant board).
 */
@Injectable()
export class SnapshotFanoutService {
  private readonly logger = new Logger(SnapshotFanoutService.name);
  private server: Server | null = null;
  private accessCheck: RoomAccessCheck | null = null;
  /** Per-room chain so pruning never reorders snapshots of one aggregate. */
  private readonly roomQueues = new Map<string, Promise<void>>();

  bindServer(server: Server): void {
    this.server = server;
  }

  /**
   * Re-check room members on Ride snapshots past NEGOTIATING: offering drivers that were
   * not selected joined `ride:<id>` while negotiating and would otherwise keep receiving
   * the customer's ride status (found by scripts/e2e-realtime-sim.ts, 2026-10-24).
   */
  bindAccessCheck(check: RoomAccessCheck): void {
    this.accessCheck = check;
  }

  emitSnapshot(payload: SnapshotEventPayload): void {
    const room = roomForAggregate(payload.aggregateType, payload.aggregateId);
    if (!room) {
      this.logger.warn({
        msg: 'realtime.unknown_aggregate',
        aggregateType: payload.aggregateType,
        aggregateId: payload.aggregateId,
      });
      return;
    }
    if (!this.server) {
      this.logger.debug({
        msg: 'realtime.fanout_unbound',
        room,
        eventType: payload.eventType,
      });
      return;
    }
    const server = this.server;
    const check = this.accessCheck;
    if (payload.aggregateType === 'Ride' && payload.status !== 'NEGOTIATING' && check) {
      const prev = this.roomQueues.get(room) ?? Promise.resolve();
      const next = prev
        .then(() => this.pruneRoom(server, room, payload.aggregateId, check))
        .catch((error: unknown) => {
          this.logger.warn({ msg: 'realtime.prune_failed', room, error: error instanceof Error ? error.message : 'unknown' });
        })
        .then(() => {
          server.to(room).emit(SNAPSHOT_EVENT, payload);
        });
      this.roomQueues.set(room, next);
      void next.finally(() => {
        if (this.roomQueues.get(room) === next) {
          this.roomQueues.delete(room);
        }
      });
      return;
    }
    server.to(room).emit(SNAPSHOT_EVENT, payload);
    const storeId = payload.storeId?.trim();
    if (payload.aggregateType === 'FoodOrder' && storeId) {
      this.server.to(roomForStore(storeId)).emit(SNAPSHOT_EVENT, payload);
    }
  }

  /** Exposed for tests: resolves once queued Ride snapshots for the room were emitted. */
  async flush(): Promise<void> {
    await Promise.all(this.roomQueues.values());
  }

  private async pruneRoom(server: Server, room: string, rideId: string, check: RoomAccessCheck): Promise<void> {
    const sockets = await server.in(room).fetchSockets();
    const parsed = { kind: 'ride' as const, id: rideId, room };
    for (const socket of sockets) {
      const userId = (socket.data as { actor?: { userId?: string } } | undefined)?.actor?.userId;
      const allowed = userId ? await check(userId, parsed) : false;
      if (!allowed) {
        socket.leave(room);
        this.logger.log({ msg: 'realtime.room_pruned', room, userId: userId ?? null });
      }
    }
  }

  emitDriverLocation(payload: DriverLocationEventPayload): void {
    if (!this.server) {
      return;
    }
    const kind = payload.aggregateType === 'Ride' ? 'ride' : 'food';
    this.server.to(roomForDriverLocation(kind, payload.aggregateId)).emit(DRIVER_LOCATION_EVENT, payload);
  }

  emitRouteUpdated(payload: RouteUpdatedEventPayload): void {
    const room = roomForAggregate(payload.aggregateType, payload.aggregateId);
    if (!this.server || !room) {
      return;
    }
    this.server.to(room).emit(ROUTE_UPDATED_EVENT, payload);
  }

  emitRideOffers(payload: RideOffersEventPayload): void {
    if (!this.server) {
      return;
    }
    this.server.to(roomForRideOffers(payload.rideId)).emit(RIDE_OFFERS_EVENT, payload);
  }

  /**
   * Same `snapshot` hint, sent to one user's private room. Used for the assigned driver
   * so a job assigned while they're on any screen opens without polling.
   */
  emitUserSnapshot(userId: string, payload: SnapshotEventPayload): void {
    if (!this.server) {
      return;
    }
    this.server.to(roomForUser(userId)).emit(SNAPSHOT_EVENT, payload);
  }

  /** Tell the driver who lost an assigned ride (their private room only). */
  emitRideUnassigned(driverId: string, payload: RideUnassignedEventPayload): void {
    if (!this.server) {
      return;
    }
    this.server.to(roomForUser(driverId)).emit(RIDE_UNASSIGNED_EVENT_NAME, payload);
  }

  /** Announce a ride request to nearby drivers' private rooms (one emit). */
  emitRideRequest(driverIds: readonly string[], payload: RideRequestEventPayload): void {
    if (!this.server || driverIds.length === 0) {
      return;
    }
    this.server.to(driverIds.map((id) => roomForUser(id))).emit(RIDE_REQUEST_EVENT, payload);
  }

  emitFoodRequest(driverIds: readonly string[], payload: FoodRequestEventPayload): void {
    if (!this.server || driverIds.length === 0) {
      return;
    }
    this.server.to(driverIds.map((id) => roomForUser(id))).emit(FOOD_REQUEST_EVENT, payload);
  }

  emitPartnerStatus(payload: PartnerStatusEventPayload): void {
    if (!this.server) {
      return;
    }
    this.server.to(roomForUser(payload.userId)).emit(PARTNER_STATUS_EVENT, payload);
  }

  /** Transaction chat message to the participants' private rooms (never the shared job room). */
  emitChatMessage(userIds: readonly string[], payload: ChatMessageEventPayload): void {
    if (!this.server || userIds.length === 0) {
      return;
    }
    this.server.to(userIds.map((id) => roomForUser(id))).emit(CHAT_MESSAGE_EVENT, payload);
  }

  /** New inbox row(s) for these users (their private rooms only). */
  emitInbox(userIds: readonly string[], payload: InboxEventPayload): void {
    if (!this.server || userIds.length === 0) {
      return;
    }
    this.server.to(userIds.map((id) => roomForUser(id))).emit(INBOX_EVENT, payload);
  }

  emitCall(payload: CallEventPayload): void {
    if (!this.server) {
      return;
    }
    this.server
      .to([roomForUser(payload.callerUserId), roomForUser(payload.calleeUserId)])
      .emit(CALL_EVENT, payload);
  }
}
