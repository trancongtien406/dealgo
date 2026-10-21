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
import { INBOX_REPOSITORY } from '../inbox/inbox.constants.js';
import type { InboxRepository } from '../inbox/inbox.repository.js';
import { AccountSettingsService } from '../../account-settings/account-settings.service.js';
import { statusInboxText } from '../inbox/inbox-text.js';
import { OUTBOX_REPOSITORY } from './outbox.constants.js';
import type { OutboxPendingRow, OutboxRepository } from './outbox.repository.js';

const DEFAULT_BATCH = 50;

/**
 * Claims pending outbox rows, marks processed, then fans out snapshot + push mock.
 * Socket/push delivery is best-effort; clients must GET authoritative state on reconnect.
 */
/** Users per inbox/push batch when fanning out a campaign. */
export const CAMPAIGN_BATCH_SIZE = 500;

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
    @Optional() @Inject(INBOX_REPOSITORY) private readonly inbox?: InboxRepository,
    @Optional() private readonly prefs?: AccountSettingsService,
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
    const text = statusInboxText(row.aggregateType, status);
    const title = text?.title ?? `${row.aggregateType} update`;
    const body = text?.body ?? `Status: ${status}`;
    const data = {
      aggregateType: row.aggregateType,
      aggregateId: row.aggregateId,
      status,
      eventType: row.eventType,
    };
    if (text) {
      await this.writeInbox(userIds, row.eventKey, text.category, title, body, data);
    }
    const pushUsers = text && this.prefs
      ? await this.prefs.filterRecipients(userIds, text.category)
      : userIds;
    for (const userId of pushUsers) {
      await this.push.send({ userId, title, body, data });
    }
  }

  /**
   * Campaigns reach every targeted user's inbox, in keyset batches (no recipient cap).
   * FCM pushes still go only to users with a registered device token.
   */
  private async pushCampaign(row: OutboxPendingRow): Promise<void> {
    const payload = row.payload as {
      title?: string;
      body?: string;
      audience?: string;
      code?: string;
    };
    const title = typeof payload.title === 'string' ? payload.title : 'DealGo';
    const body = typeof payload.body === 'string' ? payload.body : '';
    const audience = typeof payload.audience === 'string' ? payload.audience : 'ALL';
    const data = {
      aggregateType: row.aggregateType,
      aggregateId: row.aggregateId,
      status: 'SENDING',
      eventType: row.eventType,
      code: typeof payload.code === 'string' ? payload.code : '',
    };
    if (!this.push) {
      this.logger.warn({
        msg: 'outbox.campaign_push_unavailable',
        eventKey: row.eventKey,
      });
    }
    let recipients = 0;
    let pushed = 0;
    for await (const userIds of this.campaignAudienceBatches(audience)) {
      recipients += userIds.length;
      await this.writeInbox(userIds, row.eventKey, 'PROMOTION', title, body, data);
      if (!this.push) {
        continue;
      }
      for (const userId of await this.usersWithPushTokens(userIds)) {
        await this.push.send({ userId, title, body, data });
        pushed += 1;
      }
    }
    this.logger.log({
      msg: 'outbox.campaign_push_fanout',
      eventKey: row.eventKey,
      audience,
      recipients,
      pushed,
    });
  }

  /** Inbox rows are keyed by eventKey per user, so a retried relay does not duplicate them. */
  private async writeInbox(
    userIds: string[],
    eventKey: string,
    category: 'RIDE' | 'FOOD' | 'PROMOTION' | 'SYSTEM' | 'CHAT' | 'NEWS',
    title: string,
    body: string,
    data: Record<string, string>,
  ): Promise<void> {
    if (!this.inbox || userIds.length === 0) {
      return;
    }
    const allowed = this.prefs
      ? await this.prefs.filterRecipients(userIds, category)
      : userIds;
    if (allowed.length === 0) {
      return;
    }
    await this.inbox.createMany(
      allowed.map((userId) => ({ userId, category, title, body, data, sourceEventKey: eventKey })),
    );
  }

  private campaignDb() {
    if (!this.prisma) {
      throw new Error(
        'OutboxRelayService: PrismaService unavailable for campaign audience resolution',
      );
    }
    return this.prisma.db();
  }

  /** Every user in the audience, ordered by id and paged with a keyset cursor. */
  private async *campaignAudienceBatches(audience: string): AsyncGenerator<string[]> {
    const db = this.campaignDb();
    if (!db) {
      return;
    }
    const role = audienceRole(audience);
    let cursor: string | undefined;
    for (;;) {
      const rows = await db.user.findMany({
        where: role ? { roleGrants: { some: { role, status: 'ACTIVE' } } } : undefined,
        select: { id: true },
        orderBy: { id: 'asc' },
        take: CAMPAIGN_BATCH_SIZE,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      });
      if (rows.length === 0) {
        return;
      }
      yield rows.map((r) => r.id);
      if (rows.length < CAMPAIGN_BATCH_SIZE) {
        return;
      }
      cursor = rows[rows.length - 1]!.id;
    }
  }

  private async usersWithPushTokens(userIds: string[]): Promise<string[]> {
    const db = this.campaignDb();
    if (!db || userIds.length === 0) {
      return [];
    }
    const tokens = await db.pushDeviceToken.findMany({
      where: { userId: { in: userIds } },
      select: { userId: true },
      distinct: ['userId'],
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
  const storeId = storeIdFromPayload(row.payload);
  return {
    eventType: row.eventType,
    aggregateType: row.aggregateType,
    aggregateId: row.aggregateId,
    status,
    revision: row.eventKey,
    occurredAt: now.toISOString(),
    ...(storeId ? { storeId } : {}),
  };
}

function storeIdFromPayload(payload: unknown): string | undefined {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return undefined;
  }
  const raw = (payload as Record<string, unknown>).storeId;
  return typeof raw === 'string' && raw.trim() ? raw.trim() : undefined;
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
