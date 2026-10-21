import { randomUUID } from 'node:crypto';

export type InboxCategory = 'RIDE' | 'FOOD' | 'PROMOTION' | 'SYSTEM' | 'CHAT' | 'NEWS';

export type InboxItem = {
  id: string;
  category: InboxCategory;
  title: string;
  body: string;
  data: Record<string, string> | null;
  readAt: Date | null;
  createdAt: Date;
};

export type NewInboxItem = {
  userId: string;
  category: InboxCategory;
  title: string;
  body: string;
  data?: Record<string, string>;
  /** Outbox eventKey; makes relay retries idempotent per user. */
  sourceEventKey: string;
};

export type InboxPage = {
  items: InboxItem[];
  total: number;
  unreadCount: number;
};

export type InboxListQuery = {
  page: number;
  limit: number;
  unreadOnly?: boolean;
  category?: InboxCategory;
};

export interface InboxRepository {
  /** Inserts rows, skipping (userId, sourceEventKey) duplicates. Returns inserted count. */
  createMany(rows: NewInboxItem[]): Promise<number>;
  list(userId: string, query: InboxListQuery): Promise<InboxPage>;
  /** Marks one row read for its owner; null when it is not theirs. */
  markRead(userId: string, id: string, now: Date): Promise<InboxItem | null>;
  markAllRead(userId: string, now: Date): Promise<number>;
}

type StoredInbox = InboxItem & { userId: string; sourceEventKey: string };

/** Test-only store; production resolves PrismaInboxRepository. */
export class MemoryInboxRepository implements InboxRepository {
  private readonly rows: StoredInbox[] = [];

  async createMany(rows: NewInboxItem[]): Promise<number> {
    let inserted = 0;
    for (const row of rows) {
      const duplicate = this.rows.some(
        (r) => r.userId === row.userId && r.sourceEventKey === row.sourceEventKey,
      );
      if (duplicate) {
        continue;
      }
      this.rows.push({
        id: randomUUID(),
        userId: row.userId,
        category: row.category,
        title: row.title,
        body: row.body,
        data: row.data ?? null,
        sourceEventKey: row.sourceEventKey,
        readAt: null,
        createdAt: new Date(Date.now() + inserted),
      });
      inserted += 1;
    }
    return inserted;
  }

  async list(userId: string, query: InboxListQuery): Promise<InboxPage> {
    const mine = this.rows.filter((r) => r.userId === userId);
    const filtered = mine
      .filter((r) => (query.unreadOnly ? r.readAt === null : true))
      .filter((r) => (query.category ? r.category === query.category : true))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    const start = (query.page - 1) * query.limit;
    return {
      items: filtered.slice(start, start + query.limit).map(copy),
      total: filtered.length,
      unreadCount: mine.filter((r) => r.readAt === null).length,
    };
  }

  async markRead(userId: string, id: string, now: Date): Promise<InboxItem | null> {
    const row = this.rows.find((r) => r.id === id && r.userId === userId);
    if (!row) {
      return null;
    }
    row.readAt ??= now;
    return copy(row);
  }

  async markAllRead(userId: string, now: Date): Promise<number> {
    let updated = 0;
    for (const row of this.rows) {
      if (row.userId === userId && row.readAt === null) {
        row.readAt = now;
        updated += 1;
      }
    }
    return updated;
  }
}

function copy(row: StoredInbox): InboxItem {
  return {
    id: row.id,
    category: row.category,
    title: row.title,
    body: row.body,
    data: row.data ? { ...row.data } : null,
    readAt: row.readAt,
    createdAt: row.createdAt,
  };
}
