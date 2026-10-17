import type { PrismaClient } from '../../../generated/prisma/client.js';
import type { OutboxPendingRow, OutboxRepository } from './outbox.repository.js';

export class PrismaOutboxRepository implements OutboxRepository {
  constructor(private readonly db: PrismaClient) {}

  async claimPending(
    limit: number,
    now = new Date(),
    lockTtlMs = 60_000,
  ): Promise<OutboxPendingRow[]> {
    const cutoff = new Date(now.getTime() - lockTtlMs);
    const rows = await this.db.$queryRaw<
      Array<{
        id: string;
        eventKey: string;
        aggregateType: string;
        aggregateId: string;
        eventType: string;
        payload: unknown;
        createdAt: Date;
        attempts: number;
      }>
    >`
      WITH claimable AS (
        SELECT id
        FROM "outbox_messages"
        WHERE "processedAt" IS NULL
          AND ("lockedAt" IS NULL OR "lockedAt" < ${cutoff})
        ORDER BY "createdAt" ASC, id ASC
        LIMIT ${limit}
        FOR UPDATE SKIP LOCKED
      )
      UPDATE "outbox_messages" m
      SET "lockedAt" = ${now}, "attempts" = m."attempts" + 1
      FROM claimable c
      WHERE m.id = c.id
      RETURNING m.id, m."eventKey", m."aggregateType", m."aggregateId", m."eventType", m.payload, m."createdAt", m.attempts;
    `;

    return rows.map((row) => ({
      id: row.id,
      eventKey: row.eventKey,
      aggregateType: row.aggregateType,
      aggregateId: row.aggregateId,
      eventType: row.eventType,
      payload: row.payload,
      createdAt: row.createdAt,
      attempts: row.attempts,
    }));
  }

  async releaseLock(id: string): Promise<void> {
    await this.db.outboxMessage.updateMany({
      where: { id, processedAt: null },
      data: { lockedAt: null },
    });
  }

  async listPending(limit: number): Promise<OutboxPendingRow[]> {
    const rows = await this.db.outboxMessage.findMany({
      where: { processedAt: null },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: limit,
    });
    return rows.map((row) => ({
      id: row.id,
      eventKey: row.eventKey,
      aggregateType: row.aggregateType,
      aggregateId: row.aggregateId,
      eventType: row.eventType,
      payload: row.payload,
      createdAt: row.createdAt,
      attempts: row.attempts,
    }));
  }

  async markProcessed(id: string, at: Date): Promise<boolean> {
    const updated = await this.db.outboxMessage.updateMany({
      where: { id, processedAt: null },
      data: { processedAt: at },
    });
    return updated.count === 1;
  }

  async bumpAttempts(id: string): Promise<void> {
    await this.db.outboxMessage.updateMany({
      where: { id, processedAt: null },
      data: { attempts: { increment: 1 } },
    });
  }
}
