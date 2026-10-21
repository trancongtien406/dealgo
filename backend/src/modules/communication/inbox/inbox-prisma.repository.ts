import type { Prisma, PrismaClient } from '../../../generated/prisma/client.js';
import type {
  InboxCategory,
  InboxItem,
  InboxListQuery,
  InboxPage,
  InboxRepository,
  NewInboxItem,
} from './inbox.repository.js';

type Row = {
  id: string;
  category: string;
  title: string;
  body: string;
  data: Prisma.JsonValue | null;
  readAt: Date | null;
  createdAt: Date;
};

const select = {
  id: true,
  category: true,
  title: true,
  body: true,
  data: true,
  readAt: true,
  createdAt: true,
} as const;

export class PrismaInboxRepository implements InboxRepository {
  constructor(private readonly db: PrismaClient) {}

  async createMany(rows: NewInboxItem[]): Promise<number> {
    if (rows.length === 0) {
      return 0;
    }
    const result = await this.db.userNotification.createMany({
      data: rows.map((row) => ({
        userId: row.userId,
        category: row.category,
        title: row.title.slice(0, 160),
        body: row.body,
        data: row.data ?? undefined,
        sourceEventKey: row.sourceEventKey,
      })),
      skipDuplicates: true,
    });
    return result.count;
  }

  async list(userId: string, query: InboxListQuery): Promise<InboxPage> {
    const where: Prisma.UserNotificationWhereInput = {
      userId,
      ...(query.unreadOnly ? { readAt: null } : {}),
      ...(query.category ? { category: query.category } : {}),
    };
    const [rows, total, unreadCount] = await Promise.all([
      this.db.userNotification.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (query.page - 1) * query.limit,
        take: query.limit,
        select,
      }),
      this.db.userNotification.count({ where }),
      this.db.userNotification.count({ where: { userId, readAt: null } }),
    ]);
    return { items: rows.map(toItem), total, unreadCount };
  }

  async markRead(userId: string, id: string, now: Date): Promise<InboxItem | null> {
    // Owner check is part of the filter, so another user's id behaves like a missing one.
    await this.db.userNotification.updateMany({
      where: { id, userId, readAt: null },
      data: { readAt: now },
    });
    const row = await this.db.userNotification.findFirst({ where: { id, userId }, select });
    return row ? toItem(row) : null;
  }

  async markAllRead(userId: string, now: Date): Promise<number> {
    const result = await this.db.userNotification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: now },
    });
    return result.count;
  }
}

function toItem(row: Row): InboxItem {
  return {
    id: row.id,
    category: row.category as InboxCategory,
    title: row.title,
    body: row.body,
    data: isStringRecord(row.data) ? row.data : null,
    readAt: row.readAt,
    createdAt: row.createdAt,
  };
}

function isStringRecord(value: unknown): value is Record<string, string> {
  return (
    !!value &&
    typeof value === 'object' &&
    !Array.isArray(value) &&
    Object.values(value).every((v) => typeof v === 'string')
  );
}
