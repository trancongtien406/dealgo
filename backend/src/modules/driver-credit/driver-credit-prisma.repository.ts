import { randomUUID } from 'node:crypto';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { PrismaLedgerRepository } from '../ledger/ledger-prisma.repository.js';
import type {
  CaptureTopUpResult,
  DriverCreditRepository,
  DriverTopUpRecord,
  DriverTopUpStatusName,
  DriverTopUpSummary,
  OpsDriverTopUpRecord,
  RefundTopUpResult,
} from './driver-credit.repository.js';

type Db = PrismaClient | Prisma.TransactionClient;

type Row = {
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

function toRecord(row: Row): DriverTopUpRecord {
  return { ...row };
}

export class PrismaDriverCreditRepository implements DriverCreditRepository {
  private readonly ledger: PrismaLedgerRepository;

  constructor(private readonly db: PrismaClient) {
    this.ledger = new PrismaLedgerRepository(db);
  }

  async isKycApproved(driverId: string): Promise<boolean> {
    const count = await this.db.partnerApplication.count({
      where: { userId: driverId, role: 'DRIVER', status: 'APPROVED' },
    });
    return count > 0;
  }

  async findById(id: string): Promise<DriverTopUpRecord | null> {
    const row = await this.db.driverTopUp.findUnique({ where: { id } });
    return row ? toRecord(row as Row) : null;
  }

  async findByProviderRef(provider: string, providerRef: string): Promise<DriverTopUpRecord | null> {
    const row = await this.db.driverTopUp.findFirst({ where: { provider, providerRef } });
    return row ? toRecord(row as Row) : null;
  }

  async findByOrderCode(orderCode: number): Promise<DriverTopUpRecord | null> {
    const row = await this.db.driverTopUp.findUnique({ where: { orderCode } });
    return row ? toRecord(row as Row) : null;
  }

  async findByIdempotencyKey(driverId: string, key: string): Promise<DriverTopUpRecord | null> {
    const row = await this.db.driverTopUp.findFirst({ where: { driverId, idempotencyKey: key } });
    return row ? toRecord(row as Row) : null;
  }

  async findPending(driverId: string): Promise<DriverTopUpRecord | null> {
    const row = await this.db.driverTopUp.findFirst({
      where: { driverId, status: 'PENDING' },
      orderBy: { createdAt: 'desc' },
    });
    return row ? toRecord(row as Row) : null;
  }

  async listByDriver(driverId: string, limit: number): Promise<DriverTopUpRecord[]> {
    const rows = await this.db.driverTopUp.findMany({
      where: { driverId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return rows.map((row) => toRecord(row as Row));
  }

  async listOps(filter: {
    driverId?: string;
    status?: DriverTopUpStatusName;
    limit: number;
  }): Promise<OpsDriverTopUpRecord[]> {
    const rows = await this.db.driverTopUp.findMany({
      where: {
        ...(filter.driverId ? { driverId: filter.driverId } : {}),
        ...(filter.status ? { status: filter.status } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: filter.limit,
      include: { driver: { select: { displayName: true, phone: true, contactPhone: true } } },
    });
    return rows.map((row) => ({
      ...toRecord(row as Row),
      driverName: row.driver?.displayName ?? null,
      driverPhone: row.driver?.phone ?? row.driver?.contactPhone ?? null,
    }));
  }

  async opsSummary(dayStart: Date): Promise<DriverTopUpSummary> {
    const [pending, paidToday, refunded, outstanding] = await Promise.all([
      this.db.driverTopUp.aggregate({
        where: { status: 'PENDING' },
        _count: { _all: true },
        _sum: { amountVnd: true },
      }),
      this.db.driverTopUp.aggregate({
        where: { paidAt: { gte: dayStart } },
        _sum: { amountVnd: true },
      }),
      this.db.driverTopUp.aggregate({ _sum: { refundedVnd: true } }),
      this.db.driverTopUp.aggregate({
        where: { remainingVnd: { gt: 0 } },
        _sum: { remainingVnd: true },
      }),
    ]);
    return {
      pendingCount: pending._count?._all ?? 0,
      pendingVnd: pending._sum?.amountVnd ?? 0,
      paidTodayVnd: paidToday._sum?.amountVnd ?? 0,
      refundedVnd: refunded._sum?.refundedVnd ?? 0,
      outstandingCreditVnd: outstanding._sum?.remainingVnd ?? 0,
    };
  }

  async findOpsById(id: string): Promise<OpsDriverTopUpRecord | null> {
    const row = await this.db.driverTopUp.findUnique({
      where: { id },
      include: { driver: { select: { displayName: true, phone: true, contactPhone: true } } },
    });
    if (!row) {
      return null;
    }
    return {
      ...toRecord(row as Row),
      driverName: row.driver?.displayName ?? null,
      driverPhone: row.driver?.phone ?? row.driver?.contactPhone ?? null,
    };
  }

  async sumPaidSince(driverId: string, since: Date): Promise<number> {
    const sum = await this.db.driverTopUp.aggregate({
      where: {
        driverId,
        status: { in: ['PAID', 'REFUND_PENDING', 'REFUNDED'] },
        paidAt: { gte: since },
      },
      _sum: { amountVnd: true },
    });
    return sum._sum.amountVnd ?? 0;
  }

  async create(input: {
    driverId: string;
    provider: string;
    amountVnd: number;
    idempotencyKey: string | null;
    expiresAt: Date;
  }): Promise<DriverTopUpRecord> {
    const row = await this.db.driverTopUp.create({
      data: {
        id: randomUUID(),
        driverId: input.driverId,
        provider: input.provider,
        amountVnd: input.amountVnd,
        idempotencyKey: input.idempotencyKey,
        expiresAt: input.expiresAt,
      },
    });
    return toRecord(row as Row);
  }

  async attachLink(
    id: string,
    link: { providerRef: string; paymentLinkId: string | null; checkoutUrl: string | null; qrCode: string | null },
  ): Promise<DriverTopUpRecord> {
    const row = await this.db.driverTopUp.update({
      where: { id },
      data: {
        providerRef: link.providerRef,
        paymentLinkId: link.paymentLinkId,
        checkoutUrl: link.checkoutUrl,
        qrCode: link.qrCode,
      },
    });
    return toRecord(row as Row);
  }

  async close(
    id: string,
    status: 'FAILED' | 'EXPIRED' | 'CANCELLED',
    reason: string | null,
  ): Promise<DriverTopUpRecord | null> {
    const updated = await this.db.driverTopUp.updateMany({
      where: { id, status: 'PENDING' },
      data: { status, failureReason: reason },
    });
    if (updated.count === 0) {
      return null;
    }
    return this.findById(id);
  }

  async closeByProviderRef(
    provider: string,
    providerRef: string,
    status: 'FAILED' | 'EXPIRED' | 'CANCELLED',
    reason: string | null,
  ): Promise<boolean> {
    const updated = await this.db.driverTopUp.updateMany({
      where: { provider, providerRef, status: 'PENDING' },
      data: { status, failureReason: reason },
    });
    return updated.count > 0;
  }

  async capture(input: {
    provider: string;
    providerRef: string;
    amountVnd: number | null;
    providerTransId: string | null;
    paidAt: Date;
  }): Promise<CaptureTopUpResult> {
    return this.db.$transaction(async (tx) => {
      const found = await tx.driverTopUp.findFirst({
        where: { provider: input.provider, providerRef: input.providerRef },
      });
      if (!found) {
        return 'NOT_FOUND';
      }
      await lockDriver(tx, found.driverId);
      const row = await tx.driverTopUp.findUnique({ where: { id: found.id } });
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
      await tx.driverTopUp.update({
        where: { id: row.id },
        data: {
          status: 'PAID',
          remainingVnd: row.amountVnd,
          providerTransId: input.providerTransId,
          paidAt: input.paidAt,
        },
      });
      await this.ledger.postWithin(tx, 'DRIVER_CREDIT_TOP_UP_CAPTURED', {
        entityType: 'DRIVER_TOP_UP',
        entityId: row.id,
        amountVnd: row.amountVnd,
      });
      return 'CAPTURED';
    });
  }

  async pendingOlderThan(before: Date, limit: number): Promise<DriverTopUpRecord[]> {
    const rows = await this.db.driverTopUp.findMany({
      where: { status: 'PENDING', createdAt: { lte: before } },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });
    return rows.map((row) => toRecord(row as Row));
  }

  async refund(input: {
    topUpId: string;
    actorUserId: string;
    reason: string;
    bankRef: string;
    at: Date;
  }): Promise<RefundTopUpResult> {
    return this.db.$transaction(async (tx) => {
      const found = await tx.driverTopUp.findUnique({ where: { id: input.topUpId } });
      if (!found) {
        return 'NOT_FOUND';
      }
      await lockDriver(tx, found.driverId);
      const row = await tx.driverTopUp.findUnique({ where: { id: found.id } });
      if (!row) {
        return 'NOT_FOUND';
      }
      if (row.status !== 'PAID' && row.status !== 'REFUND_PENDING') {
        return 'NOT_REFUNDABLE';
      }
      if (row.remainingVnd <= 0) {
        return 'NOTHING_LEFT';
      }
      const refundVnd = row.remainingVnd;
      const updated = await tx.driverTopUp.update({
        where: { id: row.id },
        data: {
          status: 'REFUNDED',
          remainingVnd: 0,
          refundedVnd: { increment: refundVnd },
          refundedAt: input.at,
          refundBankRef: input.bankRef,
          refundReason: input.reason,
        },
      });
      await this.ledger.postWithin(tx, 'DRIVER_CREDIT_REFUNDED', {
        entityType: 'DRIVER_TOP_UP',
        entityId: row.id,
        amountVnd: refundVnd,
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'DRIVER_CREDIT_REFUND',
          entityType: 'USER',
          entityId: row.driverId,
          reason: input.reason,
          metadata: { topUpId: row.id, amountVnd: refundVnd, bankRef: input.bankRef },
        },
      });
      return { status: 'REFUNDED', topUp: toRecord(updated as Row) };
    });
  }
}

async function lockDriver(tx: Db, driverId: string): Promise<void> {
  await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${driverId}::uuid FOR UPDATE`;
}
