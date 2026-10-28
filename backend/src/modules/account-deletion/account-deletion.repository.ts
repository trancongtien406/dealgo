import { randomUUID } from 'node:crypto';
import type { MemoryIdentityRepository } from '../identity/identity.repository.js';

export const ACCOUNT_DELETION_REPOSITORY = Symbol('ACCOUNT_DELETION_REPOSITORY');

/** Shown instead of the name once the purge worker has anonymized the account. */
export const DELETED_USER_DISPLAY_NAME = 'Người dùng đã xoá';

export type AccountDeletionMethodName = 'PHONE_OTP' | 'PASSWORD' | 'PASSKEY';
export type AccountDeletionStatusName = 'PENDING' | 'SCHEDULED' | 'CANCELLED' | 'PURGED';

/**
 * Why a user cannot delete the account right now (S027, DEC-PROD-037).
 * UNSETTLED_COD = platform fees accrued on cash jobs that Ops has not marked as collected.
 */
export type AccountDeletionBlockerCode =
  | 'ACTIVE_RIDE'
  | 'ACTIVE_FOOD_ORDER'
  | 'ACTIVE_DRIVER_JOB'
  | 'STORE_OPEN_ORDERS'
  | 'UNSETTLED_COD'
  | 'OPS_ACCOUNT';

export type AccountDeletionBlocker = {
  code: AccountDeletionBlockerCode;
  count?: number;
  amountVnd?: number;
};

export type AccountDeletionRecord = {
  id: string;
  userId: string;
  method: AccountDeletionMethodName;
  status: AccountDeletionStatusName;
  codeHash: string | null;
  attemptCount: number;
  expiresAt: Date;
  confirmedAt: Date | null;
  purgeAfter: Date | null;
  cancelledAt: Date | null;
  cancelledByUserId: string | null;
  purgedAt: Date | null;
  createdAt: Date;
};

export type ConfirmDeletionResult =
  | { status: 'scheduled'; record: AccountDeletionRecord }
  | { status: 'blocked'; blockers: AccountDeletionBlocker[] }
  | { status: 'stale' };

export type DriverFeeBalance = { amountVnd: number; settledThrough: Date | null };

export interface AccountDeletionRepository {
  findBlockers(userId: string): Promise<AccountDeletionBlocker[]>;
  /** Supersedes any PENDING request of the user (marked CANCELLED). */
  createRequest(input: {
    userId: string;
    method: AccountDeletionMethodName;
    codeHash: string | null;
    expiresAt: Date;
  }): Promise<AccountDeletionRecord>;
  findRequest(id: string): Promise<AccountDeletionRecord | null>;
  findLatest(userId: string): Promise<AccountDeletionRecord | null>;
  recordFailedAttempt(id: string): Promise<AccountDeletionRecord>;
  /**
   * One transaction under the user row lock: re-check blockers, soft-delete the user,
   * revoke every session, drop push tokens + driver presence, pause owned stores.
   */
  confirm(input: {
    requestId: string;
    userId: string;
    at: Date;
    purgeAfter: Date;
  }): Promise<ConfirmDeletionResult>;
  /** Ops restore during the grace period; audited. Null when nothing is scheduled. */
  cancelScheduled(input: {
    userId: string;
    actorUserId: string;
    reason: string;
    at: Date;
  }): Promise<AccountDeletionRecord | null>;
  listDue(now: Date, limit: number): Promise<AccountDeletionRecord[]>;
  /** Anonymize PII and remove personal rows; false when the request is no longer SCHEDULED. */
  purge(requestId: string, at: Date): Promise<boolean>;
  driverFeeBalance(driverId: string): Promise<DriverFeeBalance>;
  /** Ops confirms the outstanding fees were paid; audited. Null when nothing is outstanding. */
  settleDriverFees(input: {
    driverId: string;
    actorUserId: string;
    reason: string;
    at: Date;
  }): Promise<{ amountVnd: number; settledThrough: Date } | null>;
  /**
   * Ops records a partial cash movement with the driver (audited).
   * DRIVER_PAID lowers what the driver owes (may go below 0 = prepaid credit / top-up);
   * DEALGO_PAID records DealGo paying out a credit to the driver.
   */
  recordDriverPayment(input: {
    driverId: string;
    actorUserId: string;
    direction: 'DRIVER_PAID' | 'DEALGO_PAID';
    amountVnd: number;
    reason: string;
    at: Date;
  }): Promise<{ id: string; adjustmentVnd: number }>;
}

type MemoryAudit = { actorUserId: string; action: string; entityId: string; reason: string };

/**
 * Memory twin (tests / no DATABASE_URL). Ride, food and earnings data live in other memory
 * repositories, so blockers and fees are seeded through the test hooks below; the real
 * queries are exercised by test/concurrency/account-deletion.pg.spec.ts.
 */
export class MemoryAccountDeletionRepository implements AccountDeletionRepository {
  private readonly requests = new Map<string, AccountDeletionRecord>();
  private readonly blockers = new Map<string, AccountDeletionBlocker[]>();
  private readonly fees = new Map<string, number>();
  private readonly settlements = new Map<string, Date>();
  readonly audits: MemoryAudit[] = [];

  constructor(private readonly identity: MemoryIdentityRepository) {}

  /** Test hook. */
  setBlockers(userId: string, blockers: AccountDeletionBlocker[]): void {
    this.blockers.set(userId, blockers);
  }

  /** Test hook: accrued, unsettled platform fee of a driver. */
  setDriverFee(driverId: string, amountVnd: number): void {
    this.fees.set(driverId, amountVnd);
  }

  async findBlockers(userId: string): Promise<AccountDeletionBlocker[]> {
    const result = [...(this.blockers.get(userId) ?? [])];
    const fee = this.fees.get(userId) ?? 0;
    if (fee > 0) {
      result.push({ code: 'UNSETTLED_COD', amountVnd: fee });
    }
    const grants = await this.identity.listGrants(userId);
    if (grants.some((grant) => grant.role === 'OPS' && grant.status !== 'SUSPENDED')) {
      result.push({ code: 'OPS_ACCOUNT' });
    }
    return result;
  }

  async createRequest(input: {
    userId: string;
    method: AccountDeletionMethodName;
    codeHash: string | null;
    expiresAt: Date;
  }): Promise<AccountDeletionRecord> {
    for (const request of this.requests.values()) {
      if (request.userId === input.userId && request.status === 'PENDING') {
        request.status = 'CANCELLED';
        request.cancelledAt = new Date();
      }
    }
    const record: AccountDeletionRecord = {
      id: randomUUID(),
      userId: input.userId,
      method: input.method,
      status: 'PENDING',
      codeHash: input.codeHash,
      attemptCount: 0,
      expiresAt: input.expiresAt,
      confirmedAt: null,
      purgeAfter: null,
      cancelledAt: null,
      cancelledByUserId: null,
      purgedAt: null,
      createdAt: new Date(),
    };
    this.requests.set(record.id, record);
    return { ...record };
  }

  async findRequest(id: string): Promise<AccountDeletionRecord | null> {
    const record = this.requests.get(id);
    return record ? { ...record } : null;
  }

  async findLatest(userId: string): Promise<AccountDeletionRecord | null> {
    const rows = [...this.requests.values()]
      .filter((request) => request.userId === userId)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    return rows[0] ? { ...rows[0] } : null;
  }

  async recordFailedAttempt(id: string): Promise<AccountDeletionRecord> {
    const record = this.requests.get(id)!;
    record.attemptCount += 1;
    return { ...record };
  }

  async confirm(input: {
    requestId: string;
    userId: string;
    at: Date;
    purgeAfter: Date;
  }): Promise<ConfirmDeletionResult> {
    const record = this.requests.get(input.requestId);
    if (!record || record.userId !== input.userId || record.status !== 'PENDING') {
      return { status: 'stale' };
    }
    const blockers = await this.findBlockers(input.userId);
    if (blockers.length > 0) {
      return { status: 'blocked', blockers };
    }
    record.status = 'SCHEDULED';
    record.confirmedAt = input.at;
    record.purgeAfter = input.purgeAfter;
    record.codeHash = null;
    await this.identity.softDeleteUser(input.userId, input.at, input.purgeAfter);
    return { status: 'scheduled', record: { ...record } };
  }

  async cancelScheduled(input: {
    userId: string;
    actorUserId: string;
    reason: string;
    at: Date;
  }): Promise<AccountDeletionRecord | null> {
    const record = [...this.requests.values()].find(
      (request) => request.userId === input.userId && request.status === 'SCHEDULED',
    );
    if (!record) {
      return null;
    }
    record.status = 'CANCELLED';
    record.cancelledAt = input.at;
    record.cancelledByUserId = input.actorUserId;
    await this.identity.restoreUser(input.userId);
    this.audits.push({
      actorUserId: input.actorUserId,
      action: 'ACCOUNT_DELETION_CANCEL',
      entityId: input.userId,
      reason: input.reason,
    });
    return { ...record };
  }

  async listDue(now: Date, limit: number): Promise<AccountDeletionRecord[]> {
    return [...this.requests.values()]
      .filter(
        (request) =>
          request.status === 'SCHEDULED' &&
          request.purgeAfter !== null &&
          request.purgeAfter.getTime() <= now.getTime(),
      )
      .slice(0, limit)
      .map((request) => ({ ...request }));
  }

  async purge(requestId: string, at: Date): Promise<boolean> {
    const record = this.requests.get(requestId);
    if (!record || record.status !== 'SCHEDULED') {
      return false;
    }
    record.status = 'PURGED';
    record.purgedAt = at;
    await this.identity.anonymizeUser(record.userId, DELETED_USER_DISPLAY_NAME, at);
    return true;
  }

  async driverFeeBalance(driverId: string): Promise<DriverFeeBalance> {
    return {
      amountVnd: this.fees.get(driverId) ?? 0,
      settledThrough: this.settlements.get(driverId) ?? null,
    };
  }

  async settleDriverFees(input: {
    driverId: string;
    actorUserId: string;
    reason: string;
    at: Date;
  }): Promise<{ amountVnd: number; settledThrough: Date } | null> {
    const amountVnd = this.fees.get(input.driverId) ?? 0;
    if (amountVnd <= 0) {
      return null;
    }
    this.fees.set(input.driverId, 0);
    this.settlements.set(input.driverId, input.at);
    this.audits.push({
      actorUserId: input.actorUserId,
      action: 'DRIVER_FEE_SETTLE',
      entityId: input.driverId,
      reason: input.reason,
    });
    return { amountVnd, settledThrough: input.at };
  }

  async recordDriverPayment(input: {
    driverId: string;
    actorUserId: string;
    direction: 'DRIVER_PAID' | 'DEALGO_PAID';
    amountVnd: number;
    reason: string;
    at: Date;
  }): Promise<{ id: string; adjustmentVnd: number }> {
    const adjustmentVnd = input.direction === 'DRIVER_PAID' ? -input.amountVnd : input.amountVnd;
    this.fees.set(input.driverId, (this.fees.get(input.driverId) ?? 0) + adjustmentVnd);
    this.audits.push({
      actorUserId: input.actorUserId,
      action: 'DRIVER_BALANCE_PAYMENT',
      entityId: input.driverId,
      reason: input.reason,
    });
    return { id: `pay-${this.audits.length}`, adjustmentVnd };
  }
}
