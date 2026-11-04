import { randomUUID } from 'node:crypto';

export const DRIVER_CREDIT_REPOSITORY = Symbol('DRIVER_CREDIT_REPOSITORY');
export const DRIVER_TOP_UP_ADAPTERS = Symbol('DRIVER_TOP_UP_ADAPTERS');
export const DRIVER_TOP_UP_PROVIDER = Symbol('DRIVER_TOP_UP_PROVIDER');

export type DriverTopUpStatusName =
  | 'PENDING'
  | 'PAID'
  | 'EXPIRED'
  | 'CANCELLED'
  | 'REFUND_PENDING'
  | 'REFUNDED'
  | 'FAILED';

export type DriverTopUpProviderName = 'payos' | 'vnpay';

export type DriverTopUpRecord = {
  id: string;
  driverId: string;
  orderCode: number;
  provider: string;
  providerRef: string | null;
  paymentLinkId: string | null;
  amountVnd: number;
  remainingVnd: number;
  consumedVnd: number;
  refundedVnd: number;
  status: DriverTopUpStatusName;
  checkoutUrl: string | null;
  qrCode: string | null;
  providerTransId: string | null;
  idempotencyKey: string | null;
  failureReason: string | null;
  expiresAt: Date | null;
  paidAt: Date | null;
  refundedAt: Date | null;
  refundBankRef: string | null;
  refundReason: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export type CaptureTopUpResult =
  | 'CAPTURED'
  | 'ALREADY'
  | 'NOT_FOUND'
  | 'AMOUNT_MISMATCH'
  | 'NOT_PAYABLE';

/** Ops rows carry the driver identity so the board does not need a second lookup. */
export type OpsDriverTopUpRecord = DriverTopUpRecord & {
  driverName: string | null;
  driverPhone: string | null;
};

export type DriverTopUpSummary = {
  pendingCount: number;
  pendingVnd: number;
  paidTodayVnd: number;
  refundedVnd: number;
  outstandingCreditVnd: number;
};

export type RefundTopUpResult =
  | { status: 'REFUNDED'; topUp: DriverTopUpRecord }
  | 'NOT_FOUND'
  | 'NOT_REFUNDABLE'
  | 'NOTHING_LEFT';

export interface DriverCreditRepository {
  /** True when the driver has an approved KYC application (required before taking money). */
  isKycApproved(driverId: string): Promise<boolean>;
  findById(id: string): Promise<DriverTopUpRecord | null>;
  findByOrderCode(orderCode: number): Promise<DriverTopUpRecord | null>;
  findByProviderRef(provider: string, providerRef: string): Promise<DriverTopUpRecord | null>;
  findByIdempotencyKey(driverId: string, key: string): Promise<DriverTopUpRecord | null>;
  findPending(driverId: string): Promise<DriverTopUpRecord | null>;
  listByDriver(driverId: string, limit: number): Promise<DriverTopUpRecord[]>;
  listOps(filter: {
    driverId?: string;
    status?: DriverTopUpStatusName;
    limit: number;
  }): Promise<OpsDriverTopUpRecord[]>;
  /** Board totals for the ops driver-credit screen. */
  opsSummary(dayStart: Date): Promise<DriverTopUpSummary>;
  findOpsById(id: string): Promise<OpsDriverTopUpRecord | null>;
  /** Sum of PAID top-ups whose paidAt is at/after `since`. */
  sumPaidSince(driverId: string, since: Date): Promise<number>;
  create(input: {
    driverId: string;
    provider: string;
    amountVnd: number;
    idempotencyKey: string | null;
    expiresAt: Date;
  }): Promise<DriverTopUpRecord>;
  attachLink(
    id: string,
    link: { providerRef: string; paymentLinkId: string | null; checkoutUrl: string | null; qrCode: string | null },
  ): Promise<DriverTopUpRecord>;
  /** Moves a PENDING row to FAILED/EXPIRED/CANCELLED (no money moved). */
  close(id: string, status: 'FAILED' | 'EXPIRED' | 'CANCELLED', reason: string | null): Promise<DriverTopUpRecord | null>;
  /** Same, addressed by the PSP reference from a failure callback. */
  closeByProviderRef(
    provider: string,
    providerRef: string,
    status: 'FAILED' | 'EXPIRED' | 'CANCELLED',
    reason: string | null,
  ): Promise<boolean>;
  capture(input: {
    provider: string;
    providerRef: string;
    amountVnd: number | null;
    providerTransId: string | null;
    paidAt: Date;
  }): Promise<CaptureTopUpResult>;
  /** PENDING rows created before `before`, for active PSP reconciliation. */
  pendingOlderThan(before: Date, limit: number): Promise<DriverTopUpRecord[]>;
  refund(input: {
    topUpId: string;
    actorUserId: string;
    reason: string;
    bankRef: string;
    at: Date;
  }): Promise<RefundTopUpResult>;
}

const ORDER_CODE_START = 1_000_000_001;
const MAX_ROWS = 500;

/** In-memory mode: no PSP calls and no ledger, but the same lifecycle rules. */
export class MemoryDriverCreditRepository implements DriverCreditRepository {
  private readonly rows = new Map<string, DriverTopUpRecord>();
  private nextOrderCode = ORDER_CODE_START;

  async isKycApproved(): Promise<boolean> {
    return true;
  }

  async findById(id: string): Promise<DriverTopUpRecord | null> {
    return this.rows.get(id) ?? null;
  }

  async findByOrderCode(orderCode: number): Promise<DriverTopUpRecord | null> {
    return [...this.rows.values()].find((row) => row.orderCode === orderCode) ?? null;
  }

  async findByProviderRef(provider: string, providerRef: string): Promise<DriverTopUpRecord | null> {
    return (
      [...this.rows.values()].find(
        (row) => row.provider === provider && row.providerRef === providerRef,
      ) ?? null
    );
  }

  async findByIdempotencyKey(driverId: string, key: string): Promise<DriverTopUpRecord | null> {
    return (
      [...this.rows.values()].find(
        (row) => row.driverId === driverId && row.idempotencyKey === key,
      ) ?? null
    );
  }

  async findPending(driverId: string): Promise<DriverTopUpRecord | null> {
    return (
      [...this.rows.values()].find(
        (row) => row.driverId === driverId && row.status === 'PENDING',
      ) ?? null
    );
  }

  async listByDriver(driverId: string, limit: number): Promise<DriverTopUpRecord[]> {
    return [...this.rows.values()]
      .filter((row) => row.driverId === driverId)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, Math.min(limit, MAX_ROWS));
  }

  async listOps(filter: {
    driverId?: string;
    status?: DriverTopUpStatusName;
    limit: number;
  }): Promise<OpsDriverTopUpRecord[]> {
    return [...this.rows.values()]
      .filter((row) => !filter.driverId || row.driverId === filter.driverId)
      .filter((row) => !filter.status || row.status === filter.status)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, Math.min(filter.limit, MAX_ROWS))
      .map((row) => ({ ...row, driverName: null, driverPhone: null }));
  }

  async opsSummary(dayStart: Date): Promise<DriverTopUpSummary> {
    const rows = [...this.rows.values()];
    const pending = rows.filter((row) => row.status === 'PENDING');
    return {
      pendingCount: pending.length,
      pendingVnd: pending.reduce((sum, row) => sum + row.amountVnd, 0),
      paidTodayVnd: rows
        .filter((row) => row.paidAt !== null && row.paidAt.getTime() >= dayStart.getTime())
        .reduce((sum, row) => sum + row.amountVnd, 0),
      refundedVnd: rows.reduce((sum, row) => sum + row.refundedVnd, 0),
      outstandingCreditVnd: rows.reduce((sum, row) => sum + row.remainingVnd, 0),
    };
  }

  async findOpsById(id: string): Promise<OpsDriverTopUpRecord | null> {
    const row = this.rows.get(id);
    return row ? { ...row, driverName: null, driverPhone: null } : null;
  }

  async sumPaidSince(driverId: string, since: Date): Promise<number> {
    return [...this.rows.values()]
      .filter(
        (row) =>
          row.driverId === driverId &&
          row.status !== 'FAILED' &&
          row.status !== 'CANCELLED' &&
          row.paidAt !== null &&
          row.paidAt.getTime() >= since.getTime(),
      )
      .reduce((sum, row) => sum + row.amountVnd, 0);
  }

  async create(input: {
    driverId: string;
    provider: string;
    amountVnd: number;
    idempotencyKey: string | null;
    expiresAt: Date;
  }): Promise<DriverTopUpRecord> {
    const now = new Date();
    const row: DriverTopUpRecord = {
      id: randomUUID(),
      driverId: input.driverId,
      orderCode: this.nextOrderCode++,
      provider: input.provider,
      providerRef: null,
      paymentLinkId: null,
      amountVnd: input.amountVnd,
      remainingVnd: 0,
      consumedVnd: 0,
      refundedVnd: 0,
      status: 'PENDING',
      checkoutUrl: null,
      qrCode: null,
      providerTransId: null,
      idempotencyKey: input.idempotencyKey,
      failureReason: null,
      expiresAt: input.expiresAt,
      paidAt: null,
      refundedAt: null,
      refundBankRef: null,
      refundReason: null,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(row.id, row);
    return row;
  }

  async attachLink(
    id: string,
    link: { providerRef: string; paymentLinkId: string | null; checkoutUrl: string | null; qrCode: string | null },
  ): Promise<DriverTopUpRecord> {
    const row = this.rows.get(id)!;
    Object.assign(row, link, { updatedAt: new Date() });
    return row;
  }

  async close(
    id: string,
    status: 'FAILED' | 'EXPIRED' | 'CANCELLED',
    reason: string | null,
  ): Promise<DriverTopUpRecord | null> {
    const row = this.rows.get(id);
    if (!row || row.status !== 'PENDING') {
      return null;
    }
    Object.assign(row, { status, failureReason: reason, updatedAt: new Date() });
    return row;
  }

  async closeByProviderRef(
    provider: string,
    providerRef: string,
    status: 'FAILED' | 'EXPIRED' | 'CANCELLED',
    reason: string | null,
  ): Promise<boolean> {
    const row = await this.findByProviderRef(provider, providerRef);
    if (!row || row.status !== 'PENDING') {
      return false;
    }
    Object.assign(row, { status, failureReason: reason, updatedAt: new Date() });
    return true;
  }

  async capture(input: {
    provider: string;
    providerRef: string;
    amountVnd: number | null;
    providerTransId: string | null;
    paidAt: Date;
  }): Promise<CaptureTopUpResult> {
    const row = await this.findByProviderRef(input.provider, input.providerRef);
    if (!row) {
      return 'NOT_FOUND';
    }
    if (row.status === 'PAID' || row.status === 'REFUNDED') {
      return 'ALREADY';
    }
    if (row.status !== 'PENDING') {
      return 'NOT_PAYABLE';
    }
    if (input.amountVnd !== null && input.amountVnd !== row.amountVnd) {
      return 'AMOUNT_MISMATCH';
    }
    Object.assign(row, {
      status: 'PAID',
      remainingVnd: row.amountVnd,
      providerTransId: input.providerTransId,
      paidAt: input.paidAt,
      updatedAt: new Date(),
    });
    return 'CAPTURED';
  }

  async pendingOlderThan(before: Date, limit: number): Promise<DriverTopUpRecord[]> {
    return [...this.rows.values()]
      .filter((row) => row.status === 'PENDING' && row.createdAt.getTime() <= before.getTime())
      .slice(0, limit);
  }

  async refund(input: {
    topUpId: string;
    actorUserId: string;
    reason: string;
    bankRef: string;
    at: Date;
  }): Promise<RefundTopUpResult> {
    const row = this.rows.get(input.topUpId);
    if (!row) {
      return 'NOT_FOUND';
    }
    if (row.status !== 'PAID' && row.status !== 'REFUND_PENDING') {
      return 'NOT_REFUNDABLE';
    }
    if (row.remainingVnd <= 0) {
      return 'NOTHING_LEFT';
    }
    Object.assign(row, {
      status: 'REFUNDED',
      refundedVnd: row.refundedVnd + row.remainingVnd,
      remainingVnd: 0,
      refundedAt: input.at,
      refundBankRef: input.bankRef,
      refundReason: input.reason,
      updatedAt: new Date(),
    });
    return { status: 'REFUNDED', topUp: row };
  }
}
