import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { PUSH_SENDER } from '../../../integrations/push/push.constants.js';
import type { PushSender } from '../../../integrations/push/push-sender.js';
import { AccountSettingsService } from '../../account-settings/account-settings.service.js';
import { shortOrderCode } from '../notification/notification-audience.js';
import { chatPushPathFor, type PushRole } from '../notification/push-path.js';
import { isWithinContactWindow } from '../contact-window.js';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../../shared/pagination/pagination.js';
import type { RequestActor } from '../../identity/access-auth.guard.js';
import { FoodService } from '../../food-order/food.service.js';
import { PlatformSettingsService } from '../../../platform/settings/platform-settings.service.js';
import { RideService } from '../../ride/ride.service.js';
import { SnapshotFanoutService } from '../realtime/snapshot-fanout.service.js';
import { CHAT_BODY_MAX_LENGTH, CHAT_REPOSITORY } from './chat.constants.js';
import { chatError } from './chat.error.js';
import type {
  ChatContext,
  ChatMessageView,
  ChatRepository,
  FoodChatChannel,
} from './chat.repository.js';
import type { ChatMessageEventPayload } from '../realtime/realtime.constants.js';

export type PublicChatMessage = {
  id: string;
  threadId: string;
  senderUserId: string;
  body: string;
  createdAt: string;
};

/** At most one chat push per thread and recipient in this window (later messages collapse). */
export const CHAT_PUSH_THROTTLE_MS = 30_000;

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);
  private readonly lastChatPush = new Map<string, number>();

  constructor(
    @Inject(CHAT_REPOSITORY) private readonly chat: ChatRepository,
    private readonly rides: RideService,
    private readonly food: FoodService,
    private readonly settings: PlatformSettingsService,
    @Optional() @Inject(PUSH_SENDER) private readonly push?: PushSender,
    @Optional() private readonly prefs?: AccountSettingsService,
    @Optional() private readonly fanout?: SnapshotFanoutService,
  ) {}

  async listForRide(
    actor: RequestActor,
    rideId: string,
    page?: number,
    limit?: number,
  ): Promise<PageResult<PublicChatMessage>> {
    await this.assertRideParticipant(actor.userId, rideId);
    return this.list({ kind: 'ride', rideId }, page, limit);
  }

  async postForRide(
    actor: RequestActor,
    rideId: string,
    body: string,
  ): Promise<PublicChatMessage> {
    await this.assertRideParticipant(actor.userId, rideId);
    const message = await this.post({ kind: 'ride', rideId }, actor.userId, body);
    await this.announce('Ride', rideId, message);
    await this.pushChat('Ride', rideId, actor.userId);
    return message;
  }

  async listForFood(
    actor: RequestActor,
    orderId: string,
    page?: number,
    limit?: number,
    channel: FoodChatChannel = 'DRIVER',
  ): Promise<PageResult<PublicChatMessage>> {
    await this.assertFoodParticipant(actor.userId, orderId, channel);
    return this.list({ kind: 'food', foodOrderId: orderId, channel }, page, limit);
  }

  /**
   * Food order chat. `DRIVER` = customer ↔ assigned driver (the default, legacy route);
   * `MERCHANT` = customer ↔ shop. The two threads never share messages, realtime copies
   * or pushes, and each side only reaches its own counterpart.
   */
  async postForFood(
    actor: RequestActor,
    orderId: string,
    body: string,
    channel: FoodChatChannel = 'DRIVER',
  ): Promise<PublicChatMessage> {
    const access = await this.assertFoodParticipant(actor.userId, orderId, channel);
    const message = await this.post({ kind: 'food', foodOrderId: orderId, channel }, actor.userId, body);
    const counterpartId = access.counterpartId!;
    this.emit(foodRealtimeType(channel), orderId, [actor.userId, counterpartId], message);
    const recipientRole: PushRole = access.role === 'CUSTOMER' ? channel : 'CUSTOMER';
    await this.sendChatPush('FoodOrder', orderId, [[counterpartId, recipientRole, access.role]], channel);
    return message;
  }

  /**
   * Leaves a call note (missed call) in the trip / order thread, sent as the caller so it
   * reads in their bubble. Internal: no contact-window check and no chat push (the call
   * flow sends its own missed-call push).
   */
  async recordCallNote(
    aggregateType: 'Ride' | 'FoodOrder',
    aggregateId: string,
    senderUserId: string,
    body: string,
  ): Promise<void> {
    const context: ChatContext =
      aggregateType === 'Ride'
        ? { kind: 'ride', rideId: aggregateId }
        : { kind: 'food', foodOrderId: aggregateId, channel: 'DRIVER' };
    const message = await this.chat.postMessage(context, senderUserId, body);
    await this.announce(aggregateType, aggregateId, publish(message));
  }

  /**
   * Realtime copy of a new message to both participants' private `user:` rooms, so an open
   * chat updates with no polling and a closed one can show an unread badge. Best effort.
   */
  private async announce(
    aggregateType: 'Ride' | 'FoodOrder',
    id: string,
    message: PublicChatMessage,
  ): Promise<void> {
    if (!this.fanout) {
      return;
    }
    try {
      const roles =
        aggregateType === 'Ride' ? await this.rides.participantRoles(id) : await this.food.participantRoles(id);
      const userIds = [roles?.customerId, roles?.driverId].filter(
        (userId): userId is string => typeof userId === 'string' && userId.length > 0,
      );
      this.emit(aggregateType, id, [...userIds, message.senderUserId], message);
    } catch (error) {
      this.logger.warn(`chat realtime failed for ${aggregateType} ${shortOrderCode(id)}: ${String(error)}`);
    }
  }

  /** Realtime copy to exactly these users' private rooms. Best effort. */
  private emit(
    aggregateType: ChatMessageEventPayload['aggregateType'],
    id: string,
    userIds: string[],
    message: PublicChatMessage,
  ): void {
    if (!this.fanout) {
      return;
    }
    try {
      this.fanout.emitChatMessage([...new Set(userIds)], { aggregateType, aggregateId: id, message });
    } catch (error) {
      this.logger.warn(`chat realtime failed for ${aggregateType} ${shortOrderCode(id)}: ${String(error)}`);
    }
  }

  private async list(
    context: ChatContext,
    page?: number,
    limit?: number,
  ): Promise<PageResult<PublicChatMessage>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const result = await this.chat.listMessages(context, safePage, safeLimit);
    return {
      items: result.items.map(publish),
      page: safePage,
      limit: safeLimit,
      total: result.total,
    };
  }

  private async post(
    context: ChatContext,
    senderUserId: string,
    rawBody: string,
  ): Promise<PublicChatMessage> {
    const body = normalizeBody(rawBody);
    const message = await this.chat.postMessage(context, senderUserId, body);
    return publish(message);
  }

  /** Ride chat push: the other of customer ↔ driver. */
  private async pushChat(aggregateType: 'Ride', id: string, senderUserId: string): Promise<void> {
    if (!this.push) {
      return;
    }
    try {
      const roles = await this.rides.participantRoles(id);
      if (!roles) {
        return;
      }
      const targets: Array<[string, PushRole, PushRole]> = [];
      if (roles.customerId && roles.customerId !== senderUserId) {
        targets.push([roles.customerId, 'CUSTOMER', 'DRIVER']);
      }
      if (roles.driverId && roles.driverId !== senderUserId) {
        targets.push([roles.driverId, 'DRIVER', 'CUSTOMER']);
      }
      await this.sendChatPush(aggregateType, id, targets);
    } catch (error) {
      this.logger.warn(`chat push failed for ${aggregateType} ${shortOrderCode(id)}: ${String(error)}`);
    }
  }

  /**
   * Tells the other party a message arrived, Grab-style. Recipients are filtered by their
   * `chat` notification preference (not the ride/food toggle). The text stays out of the push
   * (chat is encrypted at rest); the tap opens the page that hosts the chat sheet. Best
   * effort: a push failure never fails the send. Targets are [userId, recipientRole, senderRole].
   */
  private async sendChatPush(
    aggregateType: 'Ride' | 'FoodOrder',
    id: string,
    targets: Array<[string, PushRole, PushRole]>,
    channel: FoodChatChannel = 'DRIVER',
  ): Promise<void> {
    if (!this.push || targets.length === 0) {
      return;
    }
    try {
      const allowed = this.prefs
        ? new Set(await this.prefs.filterRecipients(targets.map(([u]) => u), 'CHAT'))
        : new Set(targets.map(([u]) => u));
      const now = Date.now();
      for (const [userId, role, senderRole] of targets) {
        const key = `${aggregateType}:${channel}:${id}:${userId}`;
        if (!allowed.has(userId) || now - (this.lastChatPush.get(key) ?? 0) < CHAT_PUSH_THROTTLE_MS) {
          continue;
        }
        this.lastChatPush.set(key, now);
        const from = senderRole === 'DRIVER' ? 'tài xế' : senderRole === 'MERCHANT' ? 'quán' : 'khách';
        await this.push.send({
          userId,
          title: `Tin nhắn mới từ ${from}`,
          body: `${aggregateType === 'Ride' ? 'Chuyến' : 'Đơn'} ${shortOrderCode(id)}: mở ứng dụng để xem.`,
          data: {
            aggregateType,
            aggregateId: id,
            eventType: 'Chat.message',
            role,
            ...(aggregateType === 'FoodOrder' ? { channel } : {}),
            path: chatPushPathFor({ aggregateType, aggregateId: id, role, channel }) ?? '',
          },
          collapseKey: `chat-${channel === 'MERCHANT' ? 'shop-' : ''}${id}`,
        });
      }
      if (this.lastChatPush.size > 5_000) {
        for (const [key, at] of this.lastChatPush) {
          if (now - at > CHAT_PUSH_THROTTLE_MS) this.lastChatPush.delete(key);
        }
      }
    } catch (error) {
      this.logger.warn(`chat push failed for ${aggregateType} ${shortOrderCode(id)}: ${String(error)}`);
    }
  }

  private async assertRideParticipant(userId: string, rideId: string): Promise<void> {
    if (!(await this.rides.canSubscribe(userId, rideId))) {
      throw chatError('CHAT_FORBIDDEN');
    }
    const meta = await this.rides.contactMeta(rideId);
    if (!meta || !(await this.allowContact('ride', meta.status, meta.updatedAt))) {
      throw chatError('CHAT_WINDOW_CLOSED');
    }
  }

  private async assertFoodParticipant(
    userId: string,
    orderId: string,
    channel: FoodChatChannel,
  ): Promise<{ role: PushRole; counterpartId: string | null }> {
    const access = await this.food.chatAccess(userId, orderId, channel);
    if (!access) {
      throw chatError('CHAT_FORBIDDEN');
    }
    if (!access.counterpartId) {
      // The driver thread opens only once a driver is assigned.
      throw chatError('CHAT_NO_COUNTERPART');
    }
    const meta = await this.food.contactMeta(orderId);
    if (!meta || !(await this.allowContact('food', meta.status, meta.updatedAt))) {
      throw chatError('CHAT_WINDOW_CLOSED');
    }
    return access;
  }

  private async allowContact(
    kind: 'ride' | 'food',
    status: string,
    updatedAt: Date,
  ): Promise<boolean> {
    const windowMinutes = await this.settings.getNumber('CONTACT_WINDOW_MINUTES');
    return isWithinContactWindow({
      kind,
      status,
      updatedAt,
      now: new Date(),
      windowMinutes,
    });
  }
}

function normalizeBody(raw: string): string {
  const body = raw.trim();
  if (!body || body.length > CHAT_BODY_MAX_LENGTH) {
    throw chatError('CHAT_BODY_INVALID');
  }
  return body;
}

function publish(message: ChatMessageView): PublicChatMessage {
  return {
    id: message.id,
    threadId: message.threadId,
    senderUserId: message.senderUserId,
    body: message.body,
    createdAt: message.createdAt.toISOString(),
  };
}

/** Realtime aggregate name: the shop thread is its own conversation on the client. */
export function foodRealtimeType(channel: FoodChatChannel): 'FoodOrder' | 'FoodOrderShop' {
  return channel === 'MERCHANT' ? 'FoodOrderShop' : 'FoodOrder';
}
