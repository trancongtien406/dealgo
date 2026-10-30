import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { FoodService } from '../../food-order/food.service.js';
import { PrismaService } from '../../../platform/database/prisma.service.js';
import {
  PUSH_NOTABLE_FOOD_STATUSES,
  PUSH_NOTABLE_RIDE_STATUSES,
  PUSH_SENDER,
} from '../../../integrations/push/push.constants.js';
import type { PushSender } from '../../../integrations/push/push-sender.js';
import { pushPathFor, type PushRole } from '../notification/push-path.js';
import type { SnapshotEventPayload } from '../realtime/realtime.constants.js';
import { SnapshotFanoutService } from '../realtime/snapshot-fanout.service.js';
import { RideService } from '../../ride/ride.service.js';
import { INBOX_REPOSITORY } from '../inbox/inbox.constants.js';
import type { InboxRepository } from '../inbox/inbox.repository.js';
import { AccountSettingsService } from '../../account-settings/account-settings.service.js';
import { statusInboxText } from '../inbox/inbox-text.js';
import {
  notificationsFor,
  foodOrderChangeNotifications,
  partnerStatusNotification,
  foodRequestNearbyNotification,
  rideUnassignedNotifications,
  type Participants,
  type RoleNotification,
} from '../notification/notification-audience.js';
import { FOOD_CHANGE_EVENT_PREFIX, RIDE_UNASSIGNED_EVENT } from './outbox.write.js';
import { resolveNewJobAlert } from '../notification/new-job-alert.js';
import { PlatformSettingsService } from '../../../platform/settings/platform-settings.service.js';
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
  /** READY food orders announced to nearby drivers → who to tell when it is no longer open. */
  private readonly openFoodRequests = new Map<string, Set<string>>();

  constructor(
    @Inject(OUTBOX_REPOSITORY) private readonly outbox: OutboxRepository,
    @Optional() private readonly fanout?: SnapshotFanoutService,
    @Optional() @Inject(PUSH_SENDER) private readonly push?: PushSender,
    @Optional() private readonly rides?: RideService,
    @Optional() private readonly food?: FoodService,
    @Optional() private readonly prisma?: PrismaService,
    @Optional() @Inject(INBOX_REPOSITORY) private readonly inbox?: InboxRepository,
    @Optional() private readonly prefs?: AccountSettingsService,
    @Optional() private readonly settings?: PlatformSettingsService,
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
        await this.emitDriverJob(row, now);
        await this.pushNotifications(row);
        this.closeFoodRequest(row);
        await this.pushFoodRequest(row);
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
    if (row.aggregateType === 'PartnerApplication') {
      this.emitPartnerStatus(row, now);
      return;
    }
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

  /** Assigned driver's private room gets the snapshot hint (replaces the app's job poll). */
  private async emitDriverJob(row: OutboxPendingRow, now: Date): Promise<void> {
    if (row.eventType === RIDE_UNASSIGNED_EVENT) {
      const drop = unassignedFromPayload(row.payload);
      if (drop && this.fanout?.emitRideUnassigned) {
        this.fanout.emitRideUnassigned(drop.droppedDriverId, {
          rideId: row.aggregateId,
          reasonCode: drop.reasonCode,
          actor: drop.actor,
          fromStatus: drop.fromStatus,
          occurredAt: now.toISOString(),
        });
      }
      return;
    }
    const payload = toSnapshotPayload(row, now);
    if (!payload || payload.status !== 'ASSIGNED' || !this.fanout?.emitUserSnapshot) {
      return;
    }
    const roles = await this.resolveRoles(row.aggregateType, row.aggregateId);
    if (roles?.driverId) {
      this.fanout.emitUserSnapshot(roles.driverId, payload);
    }
  }

  private emitPartnerStatus(row: OutboxPendingRow, now: Date): void {
    const payload = row.payload as {
      status?: unknown;
      userId?: unknown;
      role?: unknown;
      reason?: unknown;
      sections?: unknown;
    };
    if (typeof payload?.userId !== 'string' || typeof payload.status !== 'string') {
      this.logger.warn({ msg: 'outbox.partner_status_invalid', eventKey: row.eventKey });
      return;
    }
    if (!this.fanout) {
      throw new Error(
        `OutboxRelayService: SnapshotFanoutService unavailable for PartnerApplication (eventKey: ${row.eventKey})`,
      );
    }
    this.fanout.emitPartnerStatus({
      applicationId: row.aggregateId,
      userId: payload.userId,
      role: typeof payload.role === 'string' ? payload.role : '',
      status: payload.status,
      ...(typeof payload.reason === 'string' ? { reason: payload.reason } : {}),
      ...(Array.isArray(payload.sections)
        ? { sections: payload.sections.filter((s): s is string => typeof s === 'string') }
        : {}),
      occurredAt: now.toISOString(),
    });
  }

  private async pushNotifications(row: OutboxPendingRow): Promise<void> {
    if (row.aggregateType === 'NotificationCampaign') {
      await this.pushCampaign(row);
      return;
    }
    if (row.aggregateType === 'PartnerApplication') {
      const p = row.payload as { userId?: unknown; role?: unknown; status?: unknown };
      if (typeof p?.userId === 'string' && typeof p.status === 'string') {
        const n = partnerStatusNotification(p.userId, typeof p.role === 'string' ? p.role : '', p.status);
        if (n) {
          await this.deliver([n], row, {
          status: p.status,
          ...(typeof p.role === 'string' ? { partnerRole: p.role } : {}),
        });
        }
      }
      return;
    }
    if (row.aggregateType === 'FoodOrder' && row.eventType.startsWith(FOOD_CHANGE_EVENT_PREFIX)) {
      const p = row.payload as { changeId?: unknown; changeStatus?: unknown };
      const roles = await this.resolveRoles(row.aggregateType, row.aggregateId);
      if (roles && typeof p?.changeStatus === 'string') {
        await this.deliver(foodOrderChangeNotifications(row.aggregateId, p.changeStatus, roles), row, {
          changeStatus: p.changeStatus,
          ...(typeof p.changeId === 'string' ? { changeId: p.changeId } : {}),
        });
      }
      return;
    }
    if (row.eventType === RIDE_UNASSIGNED_EVENT) {
      const drop = unassignedFromPayload(row.payload);
      const roles = drop ? await this.resolveRoles(row.aggregateType, row.aggregateId) : null;
      if (drop && roles) {
        await this.deliver(
          rideUnassignedNotifications(row.aggregateId, { customerId: roles.customerId, ...drop }),
          row,
          { status: 'NEGOTIATING', reasonCode: drop.reasonCode },
        );
      }
      return;
    }
    // Multi-stop arrive/depart: snapshot hint only, never a second "trip started" push.
    if (typeof (row.payload as { stopEvent?: unknown } | null)?.stopEvent === 'string') {
      return;
    }
    const status = statusFromPayload(row.payload);
    if (!status || !isNotablePush(row.aggregateType, status)) {
      return;
    }
    const roles = await this.resolveRoles(row.aggregateType, row.aggregateId);
    if (roles) {
      await this.deliver(notificationsFor(row.aggregateType, row.aggregateId, status, roles), row, { status });
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
   * A food order turned READY and nobody claimed it yet: nearby online food drivers get a
   * high-priority push (the app may be in the background or killed, so the polled list is not
   * enough). Same admin switches as the ride request push (RIDE_REQUEST_PUSH_ENABLED /
   * RIDE_REQUEST_PUSH_MAX_DRIVERS); honours the driver's `food` notification toggle. No inbox row.
   */
  /**
   * The READY order was claimed, cancelled or failed: drivers we announced it to get a
   * `foodRequest` hint so their job list and full-screen incoming-job card drop it now.
   */
  closeFoodRequest(row: OutboxPendingRow): void {
    if (row.aggregateType !== 'FoodOrder') return;
    const drivers = this.openFoodRequests.get(row.aggregateId);
    if (!drivers || statusFromPayload(row.payload) === 'READY') return;
    this.openFoodRequests.delete(row.aggregateId);
    this.fanout?.emitFoodRequest?.([...drivers], { orderId: row.aggregateId, at: new Date().toISOString() });
  }

  async pushFoodRequest(row: OutboxPendingRow): Promise<number> {
    if (
      !this.push ||
      !this.food ||
      row.aggregateType !== 'FoodOrder' ||
      statusFromPayload(row.payload) !== 'READY' ||
      row.eventType.startsWith(FOOD_CHANGE_EVENT_PREFIX)
    ) {
      return 0;
    }
    try {
      const audience = await this.food.readyAudience(row.aggregateId);
      if (!audience || audience.driverIds.length === 0) {
        return 0;
      }
      // Open driver apps refresh their job list right away (socket); the push below is for
      // backgrounded/killed apps and follows the admin push switches.
      this.fanout?.emitFoodRequest?.(audience.driverIds, { orderId: row.aggregateId, at: new Date().toISOString() });
      this.openFoodRequests.set(row.aggregateId, new Set(audience.driverIds));
      const enabled = this.settings ? await this.settings.getBoolean('RIDE_REQUEST_PUSH_ENABLED') : true;
      const maxDrivers = this.settings ? await this.settings.getNumber('RIDE_REQUEST_PUSH_MAX_DRIVERS') : 30;
      if (!enabled || maxDrivers <= 0) {
        return 0;
      }
      const nearest = audience.driverIds.slice(0, maxDrivers);
      const allowed = this.prefs ? await this.prefs.filterRecipients(nearest, 'FOOD') : nearest;
      let sent = 0;
      for (const driverId of allowed) {
        const n = foodRequestNearbyNotification(driverId, audience.order);
        await this.push.send({
          userId: n.userId,
          title: n.title,
          body: n.body,
          data: {
            aggregateType: 'FoodOrder',
            aggregateId: row.aggregateId,
            status: 'READY',
            eventType: 'FoodOrder.request.nearby',
            role: 'DRIVER',
            path: pushPathFor({ aggregateType: 'FoodOrder', aggregateId: row.aggregateId, role: 'DRIVER', kind: 'request' }) ?? '/driver/jobs',
          },
          collapseKey: `food-request-${row.aggregateId}`,
          ttlSeconds: audience.ttlSeconds,
          urgent: true,
          alert: await resolveNewJobAlert('NEW_FOOD_JOB', driverId, { settings: this.settings, prefs: this.prefs }),
        });
        sent += 1;
      }
      return sent;
    } catch (error) {
      this.logger.warn({ msg: 'push.food_request_failed', eventKey: row.eventKey, error: String(error) });
      return 0;
    }
  }

  /** Role-aware delivery: inbox row + push per recipient, honouring notification prefs. */
  private async deliver(
    list: RoleNotification[],
    row: OutboxPendingRow,
    extra: Record<string, string>,
  ): Promise<void> {
    if (list.length === 0) {
      return;
    }
    const base: Record<string, string> = {
      aggregateType: row.aggregateType,
      aggregateId: row.aggregateId,
      eventType: row.eventType,
      ...extra,
    };
    for (const n of list) {
      const data = withTapPath(base, n.role, row, extra);
      await this.writeInbox([n.userId], row.eventKey, n.category, n.title, n.body, data);
      const allowed = this.prefs ? await this.prefs.filterRecipients([n.userId], n.category) : [n.userId];
      if (allowed.length === 0) {
        continue;
      }
      if (!this.push) {
        this.logger.warn({ msg: 'outbox.push_unavailable', eventKey: row.eventKey });
        continue;
      }
      // A new store order (PLACED) rings the merchant with the spoken "quán có đơn mới" sound.
      const newStoreOrder =
        row.aggregateType === 'FoodOrder' &&
        n.role === 'MERCHANT' &&
        data.status === 'PLACED' &&
        !row.eventType.startsWith(FOOD_CHANGE_EVENT_PREFIX);
      await this.push.send({
        userId: n.userId,
        title: n.title,
        body: n.body,
        data,
        ...(newStoreOrder
          ? {
              urgent: true,
              alert: await resolveNewJobAlert('MERCHANT_NEW_ORDER', n.userId, {
                settings: this.settings,
                prefs: this.prefs,
              }),
            }
          : {}),
      });
    }
  }

  private async resolveRoles(aggregateType: string, aggregateId: string): Promise<Participants | null> {
    const svc = (aggregateType === 'Ride' ? this.rides : aggregateType === 'FoodOrder' ? this.food : undefined) as
      | { participantRoles?: (id: string) => Promise<Participants | null> }
      | undefined;
    if (!svc || typeof svc.participantRoles !== 'function') {
      return null;
    }
    return svc.participantRoles(aggregateId);
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
      // Campaigns open the inbox; the app swaps in the signed-in role's shell.
      path: '/customer/account/notifications',
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
    const created = await this.inbox.createMany(
      allowed.map((userId) => ({ userId, category, title, body, data, sourceEventKey: eventKey })),
    );
    // A retried relay writes nothing new, so it must not bump badges again.
    if (created > 0) {
      this.fanout?.emitInbox?.(allowed, { category, at: new Date().toISOString() });
    }
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

function unassignedFromPayload(
  payload: unknown,
): { droppedDriverId: string; actor: string; reasonCode: string; fromStatus: string } | null {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return null;
  }
  const p = payload as Record<string, unknown>;
  if (typeof p.droppedDriverId !== 'string' || !p.droppedDriverId) {
    return null;
  }
  const str = (v: unknown, fallback: string) => (typeof v === 'string' && v ? v : fallback);
  return {
    droppedDriverId: p.droppedDriverId,
    actor: str(p.actor, 'SYSTEM'),
    reasonCode: str(p.reasonCode, 'UNASSIGNED'),
    fromStatus: str(p.fromStatus, 'ASSIGNED'),
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

/**
 * Add the recipient's `role` and the in-app `path` so a tap from the
 * background or a cold start lands on the right page (see push-path.ts).
 */
function withTapPath(
  base: Record<string, string>,
  role: PushRole | undefined,
  row: Pick<OutboxPendingRow, 'aggregateType' | 'aggregateId'>,
  extra: Record<string, string>,
): Record<string, string> {
  const recipient: PushRole = role ?? 'CUSTOMER';
  const path = pushPathFor({
    aggregateType: row.aggregateType,
    aggregateId: row.aggregateId,
    role: recipient,
    status: extra.status,
    partnerRole: extra.partnerRole,
  });
  return { ...base, role: recipient, ...(path ? { path } : {}) };
}
