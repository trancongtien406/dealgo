import { Inject, Injectable } from '@nestjs/common';
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
import { CHAT_BODY_MAX_LENGTH, CHAT_REPOSITORY } from './chat.constants.js';
import { chatError } from './chat.error.js';
import type { ChatContext, ChatMessageView, ChatRepository } from './chat.repository.js';

export type PublicChatMessage = {
  id: string;
  threadId: string;
  senderUserId: string;
  body: string;
  createdAt: string;
};

@Injectable()
export class ChatService {
  constructor(
    @Inject(CHAT_REPOSITORY) private readonly chat: ChatRepository,
    private readonly rides: RideService,
    private readonly food: FoodService,
    private readonly settings: PlatformSettingsService,
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
    return this.post({ kind: 'ride', rideId }, actor.userId, body);
  }

  async listForFood(
    actor: RequestActor,
    orderId: string,
    page?: number,
    limit?: number,
  ): Promise<PageResult<PublicChatMessage>> {
    await this.assertFoodParticipant(actor.userId, orderId);
    return this.list({ kind: 'food', foodOrderId: orderId }, page, limit);
  }

  async postForFood(
    actor: RequestActor,
    orderId: string,
    body: string,
  ): Promise<PublicChatMessage> {
    await this.assertFoodParticipant(actor.userId, orderId);
    return this.post({ kind: 'food', foodOrderId: orderId }, actor.userId, body);
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

  private async assertRideParticipant(userId: string, rideId: string): Promise<void> {
    if (!(await this.rides.canSubscribe(userId, rideId))) {
      throw chatError('CHAT_FORBIDDEN');
    }
    const meta = await this.rides.contactMeta(rideId);
    if (!meta || !(await this.allowContact('ride', meta.status, meta.updatedAt))) {
      throw chatError('CHAT_WINDOW_CLOSED');
    }
  }

  private async assertFoodParticipant(userId: string, orderId: string): Promise<void> {
    if (!(await this.food.canSubscribe(userId, orderId))) {
      throw chatError('CHAT_FORBIDDEN');
    }
    const meta = await this.food.contactMeta(orderId);
    if (!meta || !(await this.allowContact('food', meta.status, meta.updatedAt))) {
      throw chatError('CHAT_WINDOW_CLOSED');
    }
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
