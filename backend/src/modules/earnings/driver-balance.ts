import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';

type Db = PrismaClient | Prisma.TransactionClient;

/** What a driver owes DealGo since the last Ops settlement. */
export type DriverBalance = {
  /** Platform fees on cash jobs (job_earnings.feeVnd). */
  feesVnd: number;
  /** Signed driver_balance_adjustments (cancel/no-show fee hand-overs, credits). */
  adjustmentsVnd: number;
  /** feesVnd + adjustmentsVnd; > 0 means the driver owes DealGo. */
  amountVnd: number;
  settledThrough: Date | null;
};

export type BalanceAdjustmentInput = {
  driverId: string;
  /** > 0 the driver owes DealGo; < 0 DealGo owes the driver. */
  amountVnd: number;
  kind: string;
  refType: string;
  refId: string;
  occurredAt: Date;
};

export type BalanceAdjustment = BalanceAdjustmentInput & { id: string; createdAt: Date };

/**
 * Shared by debt blocking (ride/food dispatch) and Ops settlement (account-deletion module):
 * fees + adjustments after the latest DriverFeeSettlement, optionally only up to `until`.
 */
export async function driverBalanceOf(db: Db, driverId: string, until?: Date): Promise<DriverBalance> {
  const last = await db.driverFeeSettlement.findFirst({
    where: { driverId },
    orderBy: { settledThrough: 'desc' },
    select: { settledThrough: true },
  });
  const window: Prisma.DateTimeFilter = {};
  if (last) window.gt = last.settledThrough;
  if (until) window.lte = until;
  const bounded = Boolean(last || until);
  const [fees, adjustments] = await Promise.all([
    db.jobEarning.aggregate({
      where: { driverId, ...(bounded ? { completedAt: window } : {}) },
      _sum: { feeVnd: true },
    }),
    db.driverBalanceAdjustment.aggregate({
      where: { driverId, ...(bounded ? { occurredAt: window } : {}) },
      _sum: { amountVnd: true },
    }),
  ]);
  const feesVnd = fees._sum.feeVnd ?? 0;
  const adjustmentsVnd = adjustments._sum.amountVnd ?? 0;
  return {
    feesVnd,
    adjustmentsVnd,
    amountVnd: feesVnd + adjustmentsVnd,
    settledThrough: last?.settledThrough ?? null,
  };
}
