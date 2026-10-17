export type OutboxPendingRow = {
  id: string;
  eventKey: string;
  aggregateType: string;
  aggregateId: string;
  eventType: string;
  payload: unknown;
  createdAt: Date;
  attempts: number;
};

export interface OutboxRepository {
  claimPending(
    limit: number,
    now?: Date,
    lockTtlMs?: number,
  ): Promise<OutboxPendingRow[]>;
  releaseLock(id: string): Promise<void>;
  listPending(limit: number): Promise<OutboxPendingRow[]>;
  markProcessed(id: string, at: Date): Promise<boolean>;
  bumpAttempts(id: string): Promise<void>;
}

export class MemoryOutboxRepository implements OutboxRepository {
  private readonly rows = new Map<
    string,
    OutboxPendingRow & { processedAt: Date | null; lockedAt: Date | null }
  >();

  seed(row: OutboxPendingRow): void {
    this.rows.set(row.id, { ...row, processedAt: null, lockedAt: null });
  }

  claimPending(
    limit: number,
    now = new Date(),
    lockTtlMs = 60_000,
  ): Promise<OutboxPendingRow[]> {
    const cutoff = new Date(now.getTime() - lockTtlMs);
    const claimable = [...this.rows.values()]
      .filter(
        (row) =>
          row.processedAt === null &&
          (row.lockedAt === null || row.lockedAt < cutoff),
      )
      .sort(
        (left, right) =>
          left.createdAt.getTime() - right.createdAt.getTime() ||
          left.id.localeCompare(right.id),
      )
      .slice(0, limit);

    for (const row of claimable) {
      row.lockedAt = now;
      row.attempts += 1;
    }

    return Promise.resolve(
      claimable.map(({ processedAt: _p, lockedAt: _l, ...row }) => ({ ...row })),
    );
  }

  releaseLock(id: string): Promise<void> {
    const row = this.rows.get(id);
    if (row && row.processedAt === null) {
      row.lockedAt = null;
    }
    return Promise.resolve();
  }

  listPending(limit: number): Promise<OutboxPendingRow[]> {
    const pending = [...this.rows.values()]
      .filter((row) => row.processedAt === null)
      .sort(
        (left, right) =>
          left.createdAt.getTime() - right.createdAt.getTime() ||
          left.id.localeCompare(right.id),
      )
      .slice(0, limit)
      .map(({ processedAt: _processedAt, lockedAt: _lockedAt, ...row }) => row);
    return Promise.resolve(pending);
  }

  markProcessed(id: string, at: Date): Promise<boolean> {
    const row = this.rows.get(id);
    if (!row || row.processedAt !== null) {
      return Promise.resolve(false);
    }
    row.processedAt = at;
    return Promise.resolve(true);
  }

  bumpAttempts(id: string): Promise<void> {
    const row = this.rows.get(id);
    if (row) {
      row.attempts += 1;
    }
    return Promise.resolve();
  }
}
