import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { FoodService } from '../../food-order/food.service.js';
import { PrismaService } from '../../../platform/database/prisma.service.js';
import {
  PUSH_NOTABLE_FOOD_STATUSES,
  PUSH_NOTABLE_RIDE_STATUSES,
  PUSH_SENDER,
} from '../../../integrations/push/push.constants.js';
import type { PushSender } from '../../../integrations/push/push-sender.js';
import type { SnapshotEventPayload } from '../realtime/realtime.constants.js';
import { SnapshotFanoutService } from '../realtime/snapshot-fanout.service.js';
import { RideService } from '../../ride/ride.service.js';
import { OUTBOX_REPOSITORY } from './outbox.constants.js';
import type { OutboxPendingRow, OutboxRepository } from './outbox.repository.js';

const DEFAULT_BATCH = 50;

/**
 * Claims pending outbox rows, marks processed, then fans out snapshot + push mock.
 * Socket/push delivery is best-effort; clients must GET authoritative state on reconnect.
 */
@Injectable()
export class OutboxRelayService {
  private readonly logger = new Logger(OutboxRelayService.name);

  constructor(
    @Inject(OUTBOX_REPOSITORY) private readonly outbox: OutboxRepository,
    @Optional() private readonly fanout?: SnapshotFanoutService,
    @Optional() @Inject(PUSH_SENDER) private readonly push?: PushSender,
    @Optional() private readonly rides?: RideService,
    @Optional() private readonly food?: FoodService,
    @Optional() private readonly prisma?: PrismaService,
  ) {}

  async relayOnce(limit = DEFAULT_BATCH, now = new Date()): Promise<number> {
    const pending = await this.outbox.claimPending(limit, now);
    let processed = 0;
    for (const row of pending) {
      this.logger.log({
        msg: 'outbox.relay',
        eventKey: row.eventKey,
        eventType: row.eventType,
        aggregateType: row.aggregateType,
        aggregateId: row.aggregateId,
        attempts: row.attempts,
      });

      try {
        this.emitFanout(row, now);
        await this.pushNotifications(row);
        const ok = await this.outbox.markProcessed(row.id, now);
        if (ok) {
          processed += 1;
        }
      } catch (error) {
        this.logger.error({
          msg: 'outbox.relay_failed',
          eventKey: row.eventKey,
          attempts: row.attempts,
          error: error instanceof Error ? error.message : 'unknown',
        });
        await this.outbox.releaseLock(row.id).catch(() => undefined);
      }
    }
    return processed;
  }

  private emitFanout(row: OutboxPendingRow, now: Date): void {
    const payload = toSnapshotPayload(row, now);
    if (!payload) {
      return;
    }
    if (!this.fanout) {
      throw new Error(
        `OutboxRelayService: SnapshotFanoutService unavailable for ${row.aggregateType} (eventKey: ${row.eventKey})`,
      );
    }
    this.fanout.emitSnapshot(payload);
  }

  private async pushNotifications(row: OutboxPendingRow): Promise<void> {
    if (row.aggregateType === 'NotificationCampaign') {
      await this.pushCampaign(row);
      return;
    }
    const status = statusFromPayload(row.payload);
    if (!status || !isNotablePush(row.aggregateType, status)) {
      return;
    }
    if (!this.push) {
      throw new Error(
        `OutboxRelayService: PushSender unavailable for ${row.aggregateType} (eventKey: ${row.eventKey})`,
      );
    }
    const userIds = await this.resolveParticipants(row.aggregateType, row.aggregateId);
    if (userIds.length === 0) {
      this.logger.warn({
        msg: 'outbox.push_no_recipients',
        eventKey: row.eventKey,
        aggregateType: row.aggregateType,
        aggregateId: row.aggregateId,
      });
      return;
    }
    const title = `${row.aggregateType} update`;
    const body = `Status: ${status}`;
    const data = {
      aggregateType: row.aggregateType,
      aggregateId: row.aggregateId,
      status,
      eventType: row.eventType,
    };
    for (const userId of userIds) {
      await this.push.send({ userId, title, body, data });
    }
  }

  private async pushCampaign(row: OutboxPendingRow): Promise<void> {
    if (!this.push) {
      throw new Error(
        `OutboxRelayService: PushSender unavailable for campaign (eventKey: ${row.eventKey})`,
      );
    }
    const payload = row.payload as {
      title?: string;
      body?: string;
      audience?: string;
      code?: string;
    };
    const title = typeof payload.title === 'string' ? payload.title : 'DealGo';
    const body = typeof payload.body === 'string' ? payload.body : '';
    const audience = typeof payload.audience === 'string' ? payload.audience : 'ALL';
    const userIds = await this.resolveCampaignAudience(audience);
    const data = {
      aggregateType: row.aggregateType,
      aggregateId: row.aggregateId,
      status: 'SENDING',
      eventType: row.eventType,
      code: typeof payload.code === 'string' ? payload.code : '',
    };
    for (const userId of userIds) {
      await this.push.send({ userId, title, body, data });
    }
    this.logger.log({
      msg: 'outbox.campaign_push_fanout',
      eventKey: row.eventKey,
      audience,
      recipients: userIds.length,
    });
  }

  private async resolveCampaignAudience(audience: string): Promise<string[]> {
    if (!this.prisma) {
      throw new Error(
        'OutboxRelayService: PrismaService unavailable for campaign audience resolution',
      );
    }
    const db = this.prisma.db();
    if (!db) {
      return [];
    }
    const role = audienceRole(audience);
    const tokens = await db.pushDeviceToken.findMany({
      where: role
        ? {
            user: {
              roleGrants: {
                some: { role, status: 'ACTIVE' },
              },
            },
          }
        : undefined,
      select: { userId: true },
      distinct: ['userId'],
      take: 500,
    });
    return tokens.map((t) => t.userId);
  }

  private async resolveParticipants(
    aggregateType: string,
    aggregateId: string,
  ): Promise<string[]> {
    if (aggregateType === 'Ride') {
      if (!this.rides) {
        throw new Error(
          `OutboxRelayService: RideService unavailable for aggregateId ${aggregateId}`,
        );
      }
      return this.rides.participantUserIds(aggregateId);
    }
    if (aggregateType === 'FoodOrder') {
      if (!this.food) {
        throw new Error(
          `OutboxRelayService: FoodService unavailable for aggregateId ${aggregateId}`,
        );
      }
      return this.food.participantUserIds(aggregateId);
    }
    return [];
  }
}

function isNotablePush(aggregateType: string, status: string): boolean {
  if (aggregateType === 'Ride') {
    return PUSH_NOTABLE_RIDE_STATUSES.has(status);
  }
  if (aggregateType === 'FoodOrder') {
    return PUSH_NOTABLE_FOOD_STATUSES.has(status);
  }
  return false;
}

function toSnapshotPayload(row: OutboxPendingRow, now: Date): SnapshotEventPayload | null {
  const status = statusFromPayload(row.payload);
  if (!status) {
    return null;
  }
  return {
    eventType: row.eventType,
    aggregateType: row.aggregateType,
    aggregateId: row.aggregateId,
    status,
    revision: row.eventKey,
    occurredAt: now.toISOString(),
  };
}

function statusFromPayload(payload: unknown): string | null {
  if (!payload || typeof payload !== 'object') {
    return null;
  }
  const status = (payload as { status?: unknown }).status;
  return typeof status === 'string' && status.length > 0 ? status : null;
}

function audienceRole(
  audience: string,
): 'CUSTOMER' | 'DRIVER' | 'MERCHANT' | 'OPS' | null {
  switch (audience.toUpperCase()) {
    case 'CUSTOMER':
      return 'CUSTOMER';
    case 'DRIVER':
      return 'DRIVER';
    case 'MERCHANT':
      return 'MERCHANT';
    case 'STAFF':
      return 'OPS';
    case 'ALL':
    default:
      return null;
  }
}
