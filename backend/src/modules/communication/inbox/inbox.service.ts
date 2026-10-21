import { HttpException, Inject, Injectable } from '@nestjs/common';
import { INBOX_REPOSITORY } from './inbox.constants.js';
import type { ListInboxQueryDto } from './inbox.dto.js';
import type { InboxItem, InboxRepository } from './inbox.repository.js';

export type PublicInboxItem = Omit<InboxItem, 'readAt' | 'createdAt'> & {
  read: boolean;
  readAt: string | null;
  createdAt: string;
};

export type PublicInboxPage = {
  items: PublicInboxItem[];
  page: number;
  limit: number;
  total: number;
  unreadCount: number;
};

@Injectable()
export class InboxService {
  constructor(@Inject(INBOX_REPOSITORY) private readonly inbox: InboxRepository) {}

  async list(userId: string, query: ListInboxQueryDto = {}): Promise<PublicInboxPage> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.max(1, Math.min(50, query.limit ?? 20));
    const result = await this.inbox.list(userId, {
      page,
      limit,
      unreadOnly: query.unreadOnly === true,
      category: query.category,
    });
    return {
      items: result.items.map(publish),
      page,
      limit,
      total: result.total,
      unreadCount: result.unreadCount,
    };
  }

  async markRead(userId: string, id: string, now = new Date()): Promise<PublicInboxItem> {
    const item = await this.inbox.markRead(userId, id, now);
    if (!item) {
      throw new HttpException(
        { message: 'Notification not found', errorCode: 'NOTIFICATION_NOT_FOUND' },
        404,
      );
    }
    return publish(item);
  }

  async markAllRead(userId: string, now = new Date()): Promise<{ updated: number }> {
    return { updated: await this.inbox.markAllRead(userId, now) };
  }
}

function publish(item: InboxItem): PublicInboxItem {
  return {
    ...item,
    read: item.readAt !== null,
    readAt: item.readAt?.toISOString() ?? null,
    createdAt: item.createdAt.toISOString(),
  };
}
