import { randomUUID } from 'node:crypto';
import type { EarningEntityType } from './earnings.constants.js';
import type { TxHandle } from '../../shared/tx/completion-hook.js';
import type { BalanceAdjustment, BalanceAdjustmentInput, DriverBalance } from './driver-balance.js';

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
  /** Idempotent per (kind, refType, refId, driverId), inside the caller's transaction. */
  adjustWithin(tx: TxHandle, input: BalanceAdjustmentInput): Promise<void>;
  /** Fees + adjustments since the last settlement. */
  balanceOf(driverId: string): Promise<DriverBalance>;
  listAdjustments(driverId: string, limit: number): Promise<BalanceAdjustment[]>;
  /** Jobs the driver dropped (DRIVER/SYSTEM cancels) vs completed, since `since`. */
  jobOutcomesSince(driverId: string, since: Date): Promise<{ cancelled: number; completed: number }>;
}

export class MemoryEarningsRepository implements EarningsRepository {
  private readonly rows = new Map<string, JobEarning>();
  private readonly adjustments = new Map<string, BalanceAdjustment>();

  async adjustWithin(_tx: TxHandle, input: BalanceAdjustmentInput): Promise<void> {
    const key = `${input.kind}:${input.refType}:${input.refId}:${input.driverId}`;
    if (!this.adjustments.has(key)) {
      this.adjustments.set(key, { ...input, id: randomUUID(), createdAt: new Date() });
    }
  }

  /** Memory mode has no settlements: the balance is everything ever accrued. */
  async balanceOf(driverId: string): Promise<DriverBalance> {
    let feesVnd = 0;
    for (const row of this.rows.values()) {
      if (row.driverId === driverId) feesVnd += row.feeVnd;
    }
    let adjustmentsVnd = 0;
    for (const row of this.adjustments.values()) {
      if (row.driverId === driverId) adjustmentsVnd += row.amountVnd;
    }
    return {
      feesVnd,
      adjustmentsVnd,
      amountVnd: feesVnd + adjustmentsVnd,
      creditVnd: 0,
      settledThrough: null,
    };
  }

  /** Test hook: memory has no cancellation table, so tests seed dropped jobs here. */
  readonly droppedJobs: { driverId: string; at: Date }[] = [];

  async jobOutcomesSince(driverId: string, since: Date): Promise<{ cancelled: number; completed: number }> {
    const after = (at: Date) => at.getTime() >= since.getTime();
    return {
      cancelled: this.droppedJobs.filter((row) => row.driverId === driverId && after(row.at)).length,
      completed: [...this.rows.values()].filter((row) => row.driverId === driverId && after(row.completedAt))
        .length,
    };
  }

  async listAdjustments(driverId: string, limit: number): Promise<BalanceAdjustment[]> {
    return [...this.adjustments.values()]
      .filter((row) => row.driverId === driverId)
      .sort((a, b) => b.occurredAt.getTime() - a.occurredAt.getTime())
      .slice(0, limit)
      .map((row) => ({ ...row }));
  }

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
