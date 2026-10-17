import { Injectable, Logger } from '@nestjs/common';
import type { Server } from 'socket.io';
import {
  roomForAggregate,
  SNAPSHOT_EVENT,
  type SnapshotEventPayload,
} from './realtime.constants.js';

/**
 * Thin fan-out for status snapshots. Postgres remains source of truth;
 * missing server (tests / pre-listen) is a silent no-op.
 */
@Injectable()
export class SnapshotFanoutService {
  private readonly logger = new Logger(SnapshotFanoutService.name);
  private server: Server | null = null;

  bindServer(server: Server): void {
    this.server = server;
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
    this.server.to(room).emit(SNAPSHOT_EVENT, payload);
  }
}
