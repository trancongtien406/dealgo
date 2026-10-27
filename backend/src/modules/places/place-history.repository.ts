import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';

export const PLACE_HISTORY_REPOSITORY = Symbol('PLACE_HISTORY_REPOSITORY');

export type PlaceHistoryRecord = {
  id: string;
  userId: string;
  placeKey: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
  useCount: number;
  lastUsedAt: Date;
};

export type PlaceHistoryInput = Omit<PlaceHistoryRecord, 'id' | 'useCount' | 'lastUsedAt'>;

export interface PlaceHistoryRepository {
  /** Newest first. */
  list(userId: string, limit: number): Promise<PlaceHistoryRecord[]>;
  /** Insert or bump (lastUsedAt = now, useCount + 1) the row for placeKey, then keep the newest [keep]. */
  upsert(input: PlaceHistoryInput, keep: number, now: Date): Promise<PlaceHistoryRecord>;
  remove(userId: string, id: string): Promise<boolean>;
  clear(userId: string): Promise<number>;
}

export class MemoryPlaceHistoryRepository implements PlaceHistoryRepository {
  private readonly rows = new Map<string, PlaceHistoryRecord>();

  async list(userId: string, limit: number): Promise<PlaceHistoryRecord[]> {
    return [...this.rows.values()]
      .filter((r) => r.userId === userId)
      .sort((a, b) => b.lastUsedAt.getTime() - a.lastUsedAt.getTime())
      .slice(0, limit);
  }

  async upsert(input: PlaceHistoryInput, keep: number, now: Date): Promise<PlaceHistoryRecord> {
    const current = [...this.rows.values()].find(
      (r) => r.userId === input.userId && r.placeKey === input.placeKey,
    );
    const row: PlaceHistoryRecord = current
      ? { ...current, ...input, useCount: current.useCount + 1, lastUsedAt: now }
      : { ...input, id: randomUUID(), useCount: 1, lastUsedAt: now };
    this.rows.set(row.id, row);
    const all = await this.list(input.userId, Number.MAX_SAFE_INTEGER);
    for (const stale of all.slice(keep)) this.rows.delete(stale.id);
    return row;
  }

  async remove(userId: string, id: string): Promise<boolean> {
    const row = this.rows.get(id);
    if (!row || row.userId !== userId) return false;
    this.rows.delete(id);
    return true;
  }

  async clear(userId: string): Promise<number> {
    let n = 0;
    for (const row of this.rows.values()) {
      if (row.userId === userId) {
        this.rows.delete(row.id);
        n += 1;
      }
    }
    return n;
  }
}

export class PrismaPlaceHistoryRepository implements PlaceHistoryRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(userId: string, limit: number): Promise<PlaceHistoryRecord[]> {
    return this.db.placeSearchHistory.findMany({
      where: { userId },
      orderBy: { lastUsedAt: 'desc' },
      take: limit,
    });
  }

  async upsert(input: PlaceHistoryInput, keep: number, now: Date): Promise<PlaceHistoryRecord> {
    return this.db.$transaction(async (tx) => {
      const row = await tx.placeSearchHistory.upsert({
        where: { userId_placeKey: { userId: input.userId, placeKey: input.placeKey } },
        create: { id: randomUUID(), ...input, lastUsedAt: now },
        update: {
          name: input.name,
          address: input.address,
          lat: input.lat,
          lng: input.lng,
          lastUsedAt: now,
          useCount: { increment: 1 },
        },
      });
      const stale = await tx.placeSearchHistory.findMany({
        where: { userId: input.userId },
        orderBy: { lastUsedAt: 'desc' },
        skip: keep,
        select: { id: true },
      });
      if (stale.length) {
        await tx.placeSearchHistory.deleteMany({ where: { id: { in: stale.map((s) => s.id) } } });
      }
      return row;
    });
  }

  async remove(userId: string, id: string): Promise<boolean> {
    const { count } = await this.db.placeSearchHistory.deleteMany({ where: { id, userId } });
    return count > 0;
  }

  async clear(userId: string): Promise<number> {
    const { count } = await this.db.placeSearchHistory.deleteMany({ where: { userId } });
    return count;
  }
}
