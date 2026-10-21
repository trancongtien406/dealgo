import { randomUUID } from 'node:crypto';
import type { EarningEntityType } from './earnings.constants.js';
import type { TxHandle } from '../../shared/tx/completion-hook.js';

export type JobEarning = {
  id: string;
  entityType: EarningEntityType;
  entityId: string;
  driverId: string;
  fareVnd: number;
  feeBps: number;
  feeVnd: number;
  netVnd: number;
  completedAt: Date;
};

export type NewJobEarning = Omit<JobEarning, 'id'>;

export function earningKey(entityType: EarningEntityType, entityId: string): string {
  return `${entityType}:${entityId}`;
}

export interface EarningsRepository {
  /** Inserts the snapshot once; a second call returns the stored row unchanged. */
  recordIfAbsent(input: NewJobEarning): Promise<JobEarning>;
  /** Same as recordIfAbsent, inside the caller's completion transaction. */
  recordWithin(tx: TxHandle, input: NewJobEarning): Promise<JobEarning>;
  find(entityType: EarningEntityType, entityId: string): Promise<JobEarning | null>;
  findMany(
    subjects: { entityType: EarningEntityType; entityId: string }[],
  ): Promise<Map<string, JobEarning>>;
}

export class MemoryEarningsRepository implements EarningsRepository {
  private readonly rows = new Map<string, JobEarning>();

  async recordIfAbsent(input: NewJobEarning): Promise<JobEarning> {
    const key = earningKey(input.entityType, input.entityId);
    const existing = this.rows.get(key);
    if (existing) {
      return { ...existing };
    }
    const row = { ...input, id: randomUUID() };
    this.rows.set(key, row);
    return { ...row };
  }

  /** Memory mode has no transaction to join. */
  recordWithin(_tx: TxHandle, input: NewJobEarning): Promise<JobEarning> {
    return this.recordIfAbsent(input);
  }

  async find(entityType: EarningEntityType, entityId: string): Promise<JobEarning | null> {
    const row = this.rows.get(earningKey(entityType, entityId));
    return row ? { ...row } : null;
  }

  async findMany(
    subjects: { entityType: EarningEntityType; entityId: string }[],
  ): Promise<Map<string, JobEarning>> {
    const out = new Map<string, JobEarning>();
    for (const subject of subjects) {
      const key = earningKey(subject.entityType, subject.entityId);
      const row = this.rows.get(key);
      if (row) {
        out.set(key, { ...row });
      }
    }
    return out;
  }
}
