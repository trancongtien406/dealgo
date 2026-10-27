import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import type { EarningEntityType } from './earnings.constants.js';
import type { TxHandle } from '../../shared/tx/completion-hook.js';
import {
  driverBalanceOf,
  type BalanceAdjustment,
  type BalanceAdjustmentInput,
  type DriverBalance,
} from './driver-balance.js';
import {
  earningKey,
  type EarningsRepository,
  type JobEarning,
  type NewJobEarning,
} from './earnings.repository.js';

type Row = {
  id: string;
  entityType: string;
  entityId: string;
  driverId: string;
  fareVnd: number;
  feeBps: number;
  feeVnd: number;
  netVnd: number;
  completedAt: Date;
};

function toEarning(row: Row): JobEarning {
  return {
    id: row.id,
    entityType: row.entityType as EarningEntityType,
    entityId: row.entityId,
    driverId: row.driverId,
    fareVnd: row.fareVnd,
    feeBps: row.feeBps,
    feeVnd: row.feeVnd,
    netVnd: row.netVnd,
    completedAt: row.completedAt,
  };
}

export class PrismaEarningsRepository implements EarningsRepository {
  constructor(private readonly db: PrismaClient) {}

  async recordIfAbsent(input: NewJobEarning): Promise<JobEarning> {
    try {
      return toEarning(await this.db.jobEarning.create({ data: input }));
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const existing = await this.find(input.entityType, input.entityId);
        if (existing) {
          return existing;
        }
      }
      throw error;
    }
  }

  async recordWithin(tx: TxHandle, input: NewJobEarning): Promise<JobEarning> {
    const client = tx as Prisma.TransactionClient;
    const existing = await client.jobEarning.findUnique({
      where: { entityType_entityId: { entityType: input.entityType, entityId: input.entityId } },
    });
    // No P2002 recovery here: an error would abort the transaction anyway, and the caller holds
    // the ride/order row lock, so a second writer for the same job cannot interleave.
    return toEarning(existing ?? (await client.jobEarning.create({ data: input })));
  }

  async adjustWithin(tx: TxHandle, input: BalanceAdjustmentInput): Promise<void> {
    const client = (tx as Prisma.TransactionClient | null) ?? this.db;
    await client.driverBalanceAdjustment.createMany({ data: [input], skipDuplicates: true });
  }

  balanceOf(driverId: string): Promise<DriverBalance> {
    return driverBalanceOf(this.db, driverId);
  }

  async listAdjustments(driverId: string, limit: number): Promise<BalanceAdjustment[]> {
    return this.db.driverBalanceAdjustment.findMany({
      where: { driverId },
      orderBy: { occurredAt: 'desc' },
      take: limit,
    });
  }

  async jobOutcomesSince(driverId: string, since: Date): Promise<{ cancelled: number; completed: number }> {
    const [cancelled, completed] = await Promise.all([
      this.db.driverJobCancellation.count({
        where: { driverId, actor: { in: ['DRIVER', 'SYSTEM'] }, createdAt: { gte: since } },
      }),
      this.db.jobEarning.count({ where: { driverId, completedAt: { gte: since } } }),
    ]);
    return { cancelled, completed };
  }

  async find(entityType: EarningEntityType, entityId: string): Promise<JobEarning | null> {
    const row = await this.db.jobEarning.findUnique({
      where: { entityType_entityId: { entityType, entityId } },
    });
    return row ? toEarning(row) : null;
  }

  async findMany(
    subjects: { entityType: EarningEntityType; entityId: string }[],
  ): Promise<Map<string, JobEarning>> {
    const out = new Map<string, JobEarning>();
    if (subjects.length === 0) {
      return out;
    }
    const rows = await this.db.jobEarning.findMany({
      where: {
        OR: subjects.map((subject) => ({
          entityType: subject.entityType,
          entityId: subject.entityId,
        })),
      },
    });
    for (const row of rows) {
      const earning = toEarning(row);
      out.set(earningKey(earning.entityType, earning.entityId), earning);
    }
    return out;
  }
}
