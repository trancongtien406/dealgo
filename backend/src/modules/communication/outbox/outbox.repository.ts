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
  /**
   * REL-001: a delivery failed — unlock and schedule the retry at `nextAttemptAt`, or
   * dead-letter the row (`deadLetter: true`) so it is never claimed again.
   */
  recordFailure(
    id: string,
    input: { now: Date; nextAttemptAt: Date | null; deadLetter: boolean; error: string },
  ): Promise<void>;
}

type MemoryRow = OutboxPendingRow & {
  processedAt: Date | null;
  lockedAt: Date | null;
  nextAttemptAt?: Date | null;
  deadLetteredAt?: Date | null;
  lastError?: string | null;
};

export class MemoryOutboxRepository implements OutboxRepository {
  private readonly rows = new Map<string, MemoryRow>();

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
          !row.deadLetteredAt &&
          (!row.nextAttemptAt || row.nextAttemptAt <= now) &&
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
      claimable.map(
        ({ processedAt: _p, lockedAt: _l, nextAttemptAt: _n, deadLetteredAt: _d, lastError: _e, ...row }) => ({
          ...row,
        }),
      ),
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
      .filter((row) => row.processedAt === null && !row.deadLetteredAt)
      .sort(
        (left, right) =>
          left.createdAt.getTime() - right.createdAt.getTime() ||
          left.id.localeCompare(right.id),
      )
      .slice(0, limit)
      .map(
        ({ processedAt: _p, lockedAt: _l, nextAttemptAt: _n, deadLetteredAt: _d, lastError: _e, ...row }) => row,
      );
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

  recordFailure(
    id: string,
    input: { now: Date; nextAttemptAt: Date | null; deadLetter: boolean; error: string },
  ): Promise<void> {
    const row = this.rows.get(id);
    if (row && row.processedAt === null) {
      row.lockedAt = null;
      row.nextAttemptAt = input.nextAttemptAt;
      row.lastError = input.error;
      if (input.deadLetter) row.deadLetteredAt = input.now;
    }
    return Promise.resolve();
  }

  /** Test/ops view of one row's retry state. */
  inspect(id: string): Readonly<MemoryRow> | undefined {
    return this.rows.get(id);
  }
}
