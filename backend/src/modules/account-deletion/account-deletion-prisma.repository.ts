import { randomUUID } from 'node:crypto';
import { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { driverBalanceOf } from '../earnings/driver-balance.js';
import {
  DELETED_USER_DISPLAY_NAME,
  type AccountDeletionBlocker,
  type AccountDeletionMethodName,
  type AccountDeletionRecord,
  type AccountDeletionRepository,
  type ConfirmDeletionResult,
  type DriverFeeBalance,
} from './account-deletion.repository.js';

type Db = PrismaClient | Prisma.TransactionClient;

const CUSTOMER_ACTIVE_RIDE = [
  'NEGOTIATING',
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
] as const;
const DRIVER_ACTIVE_RIDE = ['ASSIGNED', 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED', 'IN_TRIP'] as const;
const OPEN_FOOD_ORDER = ['PLACED', 'PREPARING', 'READY', 'ASSIGNED', 'PICKED_UP'] as const;
const DRIVER_ACTIVE_FOOD = ['ASSIGNED', 'PICKED_UP'] as const;

export class PrismaAccountDeletionRepository implements AccountDeletionRepository {
  constructor(private readonly db: PrismaClient) {}

  findBlockers(userId: string): Promise<AccountDeletionBlocker[]> {
    return blockersOf(this.db, userId);
  }

  async createRequest(input: {
    userId: string;
    method: AccountDeletionMethodName;
    codeHash: string | null;
    expiresAt: Date;
  }): Promise<AccountDeletionRecord> {
    return this.db.$transaction(async (tx) => {
      await tx.accountDeletionRequest.updateMany({
        where: { userId: input.userId, status: 'PENDING' },
        data: { status: 'CANCELLED', cancelledAt: new Date(), codeHash: null },
      });
      return tx.accountDeletionRequest.create({ data: { id: randomUUID(), ...input } });
    });
  }

  findRequest(id: string): Promise<AccountDeletionRecord | null> {
    return this.db.accountDeletionRequest.findUnique({ where: { id } });
  }

  findLatest(userId: string): Promise<AccountDeletionRecord | null> {
    return this.db.accountDeletionRequest.findFirst({
      where: { userId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
  }

  recordFailedAttempt(id: string): Promise<AccountDeletionRecord> {
    return this.db.accountDeletionRequest.update({
      where: { id },
      data: { attemptCount: { increment: 1 } },
    });
  }

  async confirm(input: {
    requestId: string;
    userId: string;
    at: Date;
    purgeAfter: Date;
  }): Promise<ConfirmDeletionResult> {
    return this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${input.userId}::uuid FOR UPDATE`;
      const request = await tx.accountDeletionRequest.findUnique({ where: { id: input.requestId } });
      if (!request || request.userId !== input.userId || request.status !== 'PENDING') {
        return { status: 'stale' } as const;
      }
      const blockers = await blockersOf(tx, input.userId);
      if (blockers.length > 0) {
        return { status: 'blocked', blockers } as const;
      }
      await tx.user.update({
        where: { id: input.userId },
        data: { deletedAt: input.at, purgeAfter: input.purgeAfter },
      });
      await tx.session.updateMany({
        where: { userId: input.userId, revokedAt: null },
        data: { revokedAt: input.at, revokeReason: 'USER' },
      });
      await tx.pushDeviceToken.deleteMany({ where: { userId: input.userId } });
      await tx.driverPresence.deleteMany({ where: { userId: input.userId } });
      // No new orders reach a store whose owner is leaving; Ops/merchant re-open after a restore.
      await tx.foodStore.updateMany({
        where: { ownerId: input.userId },
        data: { serviceMode: 'PAUSED', serviceModeUntil: null },
      });
      const record = await tx.accountDeletionRequest.update({
        where: { id: input.requestId },
        data: {
          status: 'SCHEDULED',
          confirmedAt: input.at,
          purgeAfter: input.purgeAfter,
          codeHash: null,
        },
      });
      return { status: 'scheduled', record } as const;
    });
  }

  async cancelScheduled(input: {
    userId: string;
    actorUserId: string;
    reason: string;
    at: Date;
  }): Promise<AccountDeletionRecord | null> {
    return this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${input.userId}::uuid FOR UPDATE`;
      const request = await tx.accountDeletionRequest.findFirst({
        where: { userId: input.userId, status: 'SCHEDULED' },
        orderBy: { createdAt: 'desc' },
      });
      if (!request) {
        return null;
      }
      const restored = await tx.user.updateMany({
        where: { id: input.userId, purgedAt: null },
        data: { deletedAt: null, purgeAfter: null },
      });
      if (restored.count !== 1) {
        return null;
      }
      const record = await tx.accountDeletionRequest.update({
        where: { id: request.id },
        data: { status: 'CANCELLED', cancelledAt: input.at, cancelledByUserId: input.actorUserId },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'ACCOUNT_DELETION_CANCEL',
          entityType: 'USER',
          entityId: input.userId,
          reason: input.reason,
          metadata: { requestId: request.id, purgeAfter: request.purgeAfter?.toISOString() ?? null },
        },
      });
      return record;
    });
  }

  listDue(now: Date, limit: number): Promise<AccountDeletionRecord[]> {
    return this.db.accountDeletionRequest.findMany({
      where: { status: 'SCHEDULED', purgeAfter: { lte: now } },
      orderBy: { purgeAfter: 'asc' },
      take: limit,
    });
  }

  async purge(requestId: string, at: Date): Promise<boolean> {
    return this.db.$transaction(async (tx) => {
      const claimed = await tx.accountDeletionRequest.updateMany({
        where: { id: requestId, status: 'SCHEDULED' },
        data: { status: 'PURGED', purgedAt: at },
      });
      if (claimed.count !== 1) {
        return false;
      }
      const { userId } = await tx.accountDeletionRequest.findUniqueOrThrow({
        where: { id: requestId },
        select: { userId: true },
      });
      // Rides, orders, ledger, earnings and ratings stay (accounting / disputes) but now point
      // at an anonymous user row; everything that identifies the person is cleared here.
      await tx.user.update({
        where: { id: userId },
        data: {
          email: null,
          phone: null,
          displayName: DELETED_USER_DISPLAY_NAME,
          dateOfBirth: null,
          gender: null,
          avatarUrl: null,
          phoneVerifiedAt: null,
          emailVerifiedAt: null,
          purgedAt: at,
        },
      });
      const byUser = { where: { userId } };
      await tx.session.deleteMany(byUser);
      await tx.pushDeviceToken.deleteMany(byUser);
      await tx.passkey.deleteMany(byUser);
      await tx.passkeyChallenge.deleteMany(byUser);
      await tx.phoneChallenge.deleteMany(byUser);
      await tx.emailVerification.deleteMany(byUser);
      await tx.passwordReset.deleteMany(byUser);
      await tx.emailSignupChallenge.deleteMany(byUser);
      await tx.customerCredential.deleteMany(byUser);
      await tx.opsCredential.deleteMany(byUser);
      await tx.savedAddress.deleteMany(byUser);
      await tx.userNotification.deleteMany(byUser);
      await tx.driverPresence.deleteMany(byUser);
      await tx.roleGrant.updateMany({ ...byUser, data: { status: 'SUSPENDED' } });
      // KYC/KYB documents: references dropped, the orphan-upload worker deletes the files.
      await tx.partnerApplication.updateMany({
        ...byUser,
        data: { metadata: {}, documents: [], reviewIssues: [] },
      });
      await tx.supportTicket.updateMany({
        where: { requesterUserId: userId },
        data: { contactName: null, contact: null },
      });
      return true;
    });
  }

  driverFeeBalance(driverId: string): Promise<DriverFeeBalance> {
    return feeBalanceOf(this.db, driverId);
  }

  async settleDriverFees(input: {
    driverId: string;
    actorUserId: string;
    reason: string;
    at: Date;
  }): Promise<{ amountVnd: number; settledThrough: Date } | null> {
    return this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${input.driverId}::uuid FOR UPDATE`;
      const balance = await feeBalanceOf(tx, input.driverId, input.at);
      if (balance.amountVnd <= 0) {
        return null;
      }
      await tx.driverFeeSettlement.create({
        data: {
          id: randomUUID(),
          driverId: input.driverId,
          amountVnd: balance.amountVnd,
          settledThrough: input.at,
          actorUserId: input.actorUserId,
          reason: input.reason,
        },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'DRIVER_FEE_SETTLE',
          entityType: 'USER',
          entityId: input.driverId,
          reason: input.reason,
          metadata: { amountVnd: balance.amountVnd, settledThrough: input.at.toISOString() },
        },
      });
      return { amountVnd: balance.amountVnd, settledThrough: input.at };
    });
  }

  async recordDriverPayment(input: {
    driverId: string;
    actorUserId: string;
    direction: 'DRIVER_PAID' | 'DEALGO_PAID';
    amountVnd: number;
    reason: string;
    at: Date;
  }): Promise<{ id: string; adjustmentVnd: number }> {
    const id = randomUUID();
    const adjustmentVnd = input.direction === 'DRIVER_PAID' ? -input.amountVnd : input.amountVnd;
    await this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${input.driverId}::uuid FOR UPDATE`;
      await tx.driverBalanceAdjustment.create({
        data: {
          id,
          driverId: input.driverId,
          amountVnd: adjustmentVnd,
          kind: input.direction === 'DRIVER_PAID' ? 'OPS_DRIVER_PAYMENT' : 'OPS_DRIVER_PAYOUT',
          refType: 'OPS',
          refId: id,
          occurredAt: input.at,
        },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'DRIVER_BALANCE_PAYMENT',
          entityType: 'USER',
          entityId: input.driverId,
          reason: input.reason,
          metadata: { direction: input.direction, amountVnd: input.amountVnd, adjustmentId: id },
        },
      });
    });
    return { id, adjustmentVnd };
  }
}

/**
 * Fees accrued after the latest settlement (optionally only up to `until`), plus signed
 * balance adjustments (customer cancel/no-show fee hand-overs) — one shared definition with
 * the dispatch debt check.
 */
async function feeBalanceOf(db: Db, driverId: string, until?: Date): Promise<DriverFeeBalance> {
  const balance = await driverBalanceOf(db, driverId, until);
  return { amountVnd: balance.amountVnd, settledThrough: balance.settledThrough };
}

async function blockersOf(db: Db, userId: string): Promise<AccountDeletionBlocker[]> {
  const [rides, driverRides, offers, orders, driverOrders, storeOrders, ops, fee] =
    await Promise.all([
      db.ride.count({ where: { customerId: userId, status: { in: [...CUSTOMER_ACTIVE_RIDE] } } }),
      db.ride.count({
        where: { assignedDriverId: userId, status: { in: [...DRIVER_ACTIVE_RIDE] } },
      }),
      db.rideOffer.count({
        where: { driverId: userId, status: 'PENDING', ride: { status: 'NEGOTIATING' } },
      }),
      db.foodOrder.count({ where: { customerId: userId, status: { in: [...OPEN_FOOD_ORDER] } } }),
      db.foodOrder.count({
        where: { assignedDriverId: userId, status: { in: [...DRIVER_ACTIVE_FOOD] } },
      }),
      db.foodOrder.count({
        where: { store: { ownerId: userId }, status: { in: [...OPEN_FOOD_ORDER] } },
      }),
      db.roleGrant.count({ where: { userId, role: 'OPS', status: { in: ['ACTIVE', 'PENDING'] } } }),
      feeBalanceOf(db, userId),
    ]);
  const blockers: AccountDeletionBlocker[] = [];
  if (rides > 0) blockers.push({ code: 'ACTIVE_RIDE', count: rides });
  if (orders > 0) blockers.push({ code: 'ACTIVE_FOOD_ORDER', count: orders });
  const driverJobs = driverRides + offers + driverOrders;
  if (driverJobs > 0) blockers.push({ code: 'ACTIVE_DRIVER_JOB', count: driverJobs });
  if (storeOrders > 0) blockers.push({ code: 'STORE_OPEN_ORDERS', count: storeOrders });
  if (fee.amountVnd > 0) blockers.push({ code: 'UNSETTLED_COD', amountVnd: fee.amountVnd });
  if (ops > 0) blockers.push({ code: 'OPS_ACCOUNT' });
  return blockers;
}
