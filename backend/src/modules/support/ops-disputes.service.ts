import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { normalizeLimit, normalizePage, type PageResult } from '../../shared/pagination/pagination.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { AuditLogsService } from '../../platform/audit/index.js';
import type { ResolveDisputeDto } from './ops-disputes.dto.js';

export type DisputeParty = {
  role: string;
  name: string;
  initials: string;
};

export type DisputeTimelineItem = {
  at: string;
  title: string;
};

export type DisputeMessageItem = {
  from: string;
  at: string;
  body: string;
  internal?: boolean;
};

export type DisputeChecklistItem = {
  label: string;
  status: 'Đạt' | 'Đang chờ' | 'Từ chối';
};

export type DisputeResolution =
  | 'PARTIAL_REFUND'
  | 'FULL_REFUND'
  | 'REJECTED'
  | 'EVIDENCE_REQUESTED';

export type DisputeCaseDetail = {
  id?: string;
  code: string;
  type: string;
  priority: 'HIGH' | 'MEDIUM' | 'LOW';
  status: 'OPEN' | 'AWAITING_RESPONSE' | 'INVESTIGATING' | 'RESOLVED' | 'PENDING';
  verifyStatus: 'INVESTIGATING' | 'RESOLVED' | 'REJECTED' | 'WAITING_MERCHANT';
  openedAt: string;
  orderCode: string;
  paymentId: string;
  refundCode: string;
  assignee: string;
  slaRemaining: string;
  parties: DisputeParty[];
  timeline: DisputeTimelineItem[];
  messages: DisputeMessageItem[];
  order: {
    code: string;
    service: string;
    result: string;
    payment: string;
    total: number;
    refundRequested: number;
  };
  checklist: DisputeChecklistItem[];
  reporter?: string;
  summary?: string;
  relatedCode?: string;
  createdAt?: string;
  resolution?: DisputeResolution | null;
  /** Present when money remedy was recorded as sandbox ledger journal. */
  refundSandbox?: boolean;
};

const LEDGER_REFUND_PAYABLE = 'sandbox.refund.payable';
const LEDGER_REFUND_CLEARING = 'sandbox.refund.clearing';

@Injectable()
export class OpsDisputesService {
  private readonly memory = new Map<string, DisputeCaseDetail>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLogsService: AuditLogsService,
  ) {
    this.seedDefaultDisputes();
  }

  private seedDefaultDisputes() {
    const rawCases: Array<
      Partial<DisputeCaseDetail> & {
        code: string;
        type: string;
        priority: DisputeCaseDetail['priority'];
        status: DisputeCaseDetail['status'];
        orderCode: string;
        reporter: string;
        summary: string;
        assignee: string;
        createdAt: string;
      }
    > = [
      {
        code: 'KN-240610-0245',
        createdAt: '10/06 · 14:42',
        type: 'Thiếu món / sai món',
        orderCode: 'FA-240610-0892',
        reporter: 'Trần Thị Mai Anh',
        summary: 'Khách báo thiếu 1 phần topping, yêu cầu hoàn một phần.',
        status: 'OPEN',
        priority: 'HIGH',
        assignee: 'Trần Minh',
      },
      {
        code: 'KN-240610-0244',
        createdAt: '10/06 · 13:18',
        type: 'Thời gian giao',
        orderCode: 'GH-240610-0142',
        reporter: 'Nguyễn Văn Quân',
        summary: 'Giao vượt SLA hơn 35 phút so với cam kết.',
        status: 'AWAITING_RESPONSE',
        priority: 'MEDIUM',
        assignee: 'Lê Thị Hoa',
      },
      {
        code: 'KN-240610-0243',
        createdAt: '10/06 · 12:05',
        type: 'Giá / phụ phí',
        orderCode: 'DGX-240610-1024',
        reporter: 'Phạm Thu Hà',
        summary: 'Phụ phí chờ đợi chưa được giải thích rõ trên biên nhận.',
        status: 'INVESTIGATING',
        priority: 'LOW',
        assignee: 'Nguyễn An',
      },
      {
        code: 'KN-240610-0242',
        createdAt: '10/06 · 11:40',
        type: 'Chất lượng món',
        orderCode: 'FA-240610-0888',
        reporter: 'Võ Minh Tuấn',
        summary: 'Món nguội, có ảnh bằng chứng đính kèm.',
        status: 'PENDING',
        priority: 'HIGH',
        assignee: 'Chưa phân công',
      },
      {
        code: 'KN-240610-0241',
        createdAt: '10/06 · 10:22',
        type: 'Tranh chấp',
        orderCode: 'FA-240610-0875',
        reporter: 'Highlands Coffee',
        summary: 'Cửa hàng phản đối yêu cầu hoàn vì đã giao đủ món.',
        status: 'OPEN',
        priority: 'HIGH',
        assignee: 'Trần Minh',
      },
      {
        code: 'KN-240610-0240',
        createdAt: '09/06 · 19:50',
        type: 'Đối soát COD',
        orderCode: 'GH-240609-0130',
        reporter: 'Phan Anh Tuấn',
        summary: 'Tài xế báo lệch tiền COD so với biên nhận cửa hàng.',
        status: 'RESOLVED',
        priority: 'MEDIUM',
        assignee: 'Lê Thị Hoa',
      },
      {
        code: 'KN-240610-0239',
        createdAt: '09/06 · 17:15',
        type: 'Đối tác',
        orderCode: 'TX-01028',
        reporter: 'Vũ Đức Long',
        summary: 'Khiếu nại khóa tạm tài khoản sau khi thiếu giấy tờ.',
        status: 'AWAITING_RESPONSE',
        priority: 'LOW',
        assignee: 'Nguyễn An',
      },
      {
        code: 'KN-240610-0238',
        createdAt: '09/06 · 15:08',
        type: 'Cửa hàng',
        orderCode: 'CH-00250',
        reporter: 'Trần Văn G',
        summary: 'Xin làm rõ lý do hồ sơ KYB chưa được duyệt.',
        status: 'INVESTIGATING',
        priority: 'MEDIUM',
        assignee: 'Trần Minh',
      },
    ];

    for (const c of rawCases) {
      const fullCase = buildSeedCase(c);
      this.memory.set(fullCase.code, fullCase);
    }
  }

  async list(options: {
    q?: string;
    status?: string;
    priority?: string;
    type?: string;
    party?: string;
    page?: number;
    limit?: number;
  }): Promise<PageResult<DisputeCaseDetail>> {
    const safePage = normalizePage(options.page);
    const safeLimit = normalizeLimit(options.limit);
    const db = this.prisma.db();

    if (db) {
      await this.ensurePersistedSeeds(db);
      const where = buildPrismaWhere(options);
      const [rows, total] = await Promise.all([
        db.disputeCase.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          skip: (safePage - 1) * safeLimit,
          take: safeLimit,
        }),
        db.disputeCase.count({ where }),
      ]);
      return {
        items: rows.map(mapPrismaDispute),
        page: safePage,
        limit: safeLimit,
        total,
      };
    }

    let allItems = Array.from(this.memory.values());
    allItems = filterMemory(allItems, options);
    const total = allItems.length;
    const start = (safePage - 1) * safeLimit;
    return {
      items: allItems.slice(start, start + safeLimit),
      page: safePage,
      limit: safeLimit,
      total,
    };
  }

  async getByCode(code: string): Promise<DisputeCaseDetail> {
    const db = this.prisma.db();
    if (db) {
      await this.ensurePersistedSeeds(db);
      const row = await db.disputeCase.findUnique({ where: { code } });
      if (!row) {
        throw disputeNotFound(code);
      }
      return mapPrismaDispute(row);
    }

    const dispute = this.memory.get(code);
    if (!dispute) {
      throw disputeNotFound(code);
    }
    return dispute;
  }

  async resolve(
    code: string,
    dto: ResolveDisputeDto,
    actorUserId: string,
  ): Promise<{
    success: boolean;
    dispute: DisputeCaseDetail;
    auditLogId: string;
    message: string;
    refundSandbox?: boolean;
  }> {
    if (dto.remedy === 'partial' && (dto.amount === undefined || dto.amount <= 0)) {
      throw new BadRequestException({
        message: 'Partial refund requires a positive amountVnd',
        errorCode: 'DISPUTE_REFUND_AMOUNT_REQUIRED',
      });
    }

    const db = this.prisma.db();
    if (db) {
      return this.resolvePersisted(db, code, dto, actorUserId);
    }
    return this.resolveMemory(code, dto, actorUserId);
  }

  private async resolvePersisted(
    db: NonNullable<ReturnType<PrismaService['db']>>,
    code: string,
    dto: ResolveDisputeDto,
    actorUserId: string,
  ): Promise<{
    success: boolean;
    dispute: DisputeCaseDetail;
    auditLogId: string;
    message: string;
    refundSandbox?: boolean;
  }> {
    await this.ensurePersistedSeeds(db);
    const existing = await db.disputeCase.findUnique({ where: { code } });
    if (!existing) {
      throw disputeNotFound(code);
    }

    const now = new Date();
    const timeFormatted = formatClock(now);
    const patch = applyRemedy(mapPrismaDispute(existing), dto, timeFormatted);
    const moneyRemedy = dto.remedy === 'partial' || dto.remedy === 'full';
    const amountVnd = moneyRemedy
      ? dto.remedy === 'full'
        ? patch.order.total
        : (dto.amount ?? patch.order.refundRequested)
      : 0;

    const result = await db.$transaction(async (tx) => {
      let ledgerJournalId: string | null = null;
      let refundRequestId: string | null = null;

      if (moneyRemedy) {
        ledgerJournalId = await postSandboxRefundJournal(tx as never, {
          disputeId: existing.id,
          amountVnd,
        });
        const refund = await tx.refundRequest.create({
          data: {
            id: randomUUID(),
            code: existing.refundCode,
            disputeId: existing.id,
            kind: dto.remedy === 'full' ? 'FULL' : 'PARTIAL',
            status: 'SANDBOX_RECORDED',
            amountVnd,
            reason: dto.reason,
            ledgerJournalId,
            createdByUserId: actorUserId,
          },
        });
        refundRequestId = refund.id;
      }

      const updated = await tx.disputeCase.update({
        where: { id: existing.id },
        data: {
          status: patch.status,
          verifyStatus: patch.verifyStatus,
          resolution: patch.resolution ?? null,
          timeline: patch.timeline as object[],
          messages: patch.messages as object[],
          checklist: patch.checklist as object[],
          resolvedAt:
            patch.status === 'RESOLVED' ? now : existing.resolvedAt,
          orderSnapshot: patch.order as object,
        },
      });

      const audit = await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId,
          action: 'DISPUTE_RESOLVE',
          entityType: 'DISPUTE',
          entityId: existing.id,
          reason: dto.reason,
          metadata: {
            remedy: dto.remedy,
            amount: dto.amount ?? null,
            note: dto.note ?? null,
            orderCode: existing.orderCode,
            refundSandbox: moneyRemedy,
            refundRequestId,
            ledgerJournalId,
            resolvedAt: now.toISOString(),
          },
        },
      });

      return { updated, auditId: audit.id, moneyRemedy };
    });

    const dispute = mapPrismaDispute(result.updated);
    if (result.moneyRemedy) {
      dispute.refundSandbox = true;
    }

    this.auditLogsService.record({
      actor: 'Điều phối viên vận hành',
      actorId: actorUserId,
      action: `DISPUTE_RESOLVE_${dto.remedy.toUpperCase()}`,
      target: `Khiếu nại ${code}`,
      entityType: 'DISPUTE',
      entityId: existing.id,
      reason: dto.reason,
      result: 'SUCCESS',
      metadata: {
        remedy: dto.remedy,
        amount: dto.amount,
        refundSandbox: result.moneyRemedy,
      },
    });

    return {
      success: true,
      dispute,
      auditLogId: result.auditId,
      refundSandbox: result.moneyRemedy || undefined,
      message: result.moneyRemedy
        ? 'Đã ghi nhận phương án hoàn tiền sandbox (ledger stub + RefundRequest). Chưa phải hoàn tiền PSP thật — OPEN policy.'
        : 'Đã giải quyết và lưu phương án xử lý. Bản ghi đã ghi nhận nhật ký kiểm toán.',
    };
  }

  private async resolveMemory(
    code: string,
    dto: ResolveDisputeDto,
    actorUserId: string,
  ): Promise<{
    success: boolean;
    dispute: DisputeCaseDetail;
    auditLogId: string;
    message: string;
    refundSandbox?: boolean;
  }> {
    const dispute = await this.getByCode(code);
    const now = new Date();
    const timeFormatted = formatClock(now);
    const patched = applyRemedy(dispute, dto, timeFormatted);
    const moneyRemedy = dto.remedy === 'partial' || dto.remedy === 'full';
    if (moneyRemedy) {
      patched.refundSandbox = true;
    }

    const auditItem = this.auditLogsService.record({
      actor: 'Điều phối viên vận hành',
      actorId: actorUserId,
      action: `DISPUTE_RESOLVE_${dto.remedy.toUpperCase()}`,
      target: `Khiếu nại ${code}`,
      entityType: 'DISPUTE',
      entityId: patched.id ?? code,
      reason: dto.reason,
      result: 'SUCCESS',
      metadata: {
        remedy: dto.remedy,
        amount: dto.amount,
        note: dto.note,
        orderCode: patched.orderCode,
        refundSandbox: moneyRemedy,
        resolvedAt: now.toISOString(),
      },
    });

    this.memory.set(code, patched);

    return {
      success: true,
      dispute: patched,
      auditLogId: auditItem.code,
      refundSandbox: moneyRemedy || undefined,
      message: moneyRemedy
        ? 'Đã ghi nhận phương án hoàn tiền sandbox (in-memory). Chưa phải hoàn tiền PSP thật — OPEN policy.'
        : 'Đã giải quyết và lưu phương án xử lý thành công. Bản ghi đã được đồng bộ vào hệ thống và ghi nhận nhật ký kiểm toán.',
    };
  }

  private seededPersist: Promise<void> | null = null;

  private ensurePersistedSeeds(
    db: NonNullable<ReturnType<PrismaService['db']>>,
  ): Promise<void> {
    if (!this.seededPersist) {
      this.seededPersist = (async () => {
        const count = await db.disputeCase.count();
        if (count > 0) return;
        for (const seed of this.memory.values()) {
          await db.disputeCase.create({
            data: {
              id: randomUUID(),
              code: seed.code,
              type: seed.type,
              priority: seed.priority,
              status: seed.status,
              verifyStatus: seed.verifyStatus,
              orderCode: seed.orderCode,
              paymentId: seed.paymentId,
              refundCode: seed.refundCode,
              assignee: seed.assignee,
              slaRemaining: seed.slaRemaining,
              reporterName: seed.reporter ?? 'Khách hàng',
              summary: seed.summary ?? '',
              parties: seed.parties,
              timeline: seed.timeline,
              messages: seed.messages,
              checklist: seed.checklist,
              orderSnapshot: seed.order,
              resolution: seed.resolution ?? null,
              openedAt: new Date(),
            },
          });
        }
      })().catch((error) => {
        this.seededPersist = null;
        throw error;
      });
    }
    return this.seededPersist;
  }
}

function disputeNotFound(code: string): NotFoundException {
  return new NotFoundException({
    message: `Không tìm thấy khiếu nại ${code}`,
    errorCode: 'DISPUTE_NOT_FOUND',
  });
}

function formatClock(now: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(now.getHours())}:${pad(now.getMinutes())}`;
}

function applyRemedy(
  dispute: DisputeCaseDetail,
  dto: ResolveDisputeDto,
  timeFormatted: string,
): DisputeCaseDetail {
  const next: DisputeCaseDetail = {
    ...dispute,
    timeline: [...dispute.timeline],
    messages: [...dispute.messages],
    checklist: dispute.checklist.map((c) => ({ ...c })),
    order: { ...dispute.order },
  };

  let statusTitle = '';
  let messageText = '';

  if (dto.remedy === 'evidence') {
    next.status = 'AWAITING_RESPONSE';
    next.verifyStatus = 'INVESTIGATING';
    next.resolution = 'EVIDENCE_REQUESTED';
    statusTitle = 'Yêu cầu bổ sung thêm bằng chứng xác minh';
    messageText = `[Điều phối viên] Yêu cầu các bên liên quan bổ sung bằng chứng. Lý do: ${dto.reason}`;
    next.checklist = next.checklist.map((c) =>
      c.label.includes('bằng chứng') ? { ...c, status: 'Đang chờ' } : c,
    );
  } else if (dto.remedy === 'partial') {
    next.status = 'RESOLVED';
    next.verifyStatus = 'RESOLVED';
    next.resolution = 'PARTIAL_REFUND';
    if (dto.amount !== undefined) {
      next.order.refundRequested = dto.amount;
    }
    const amtStr = dto.amount ? `${dto.amount.toLocaleString('vi-VN')} đ` : 'một phần';
    statusTitle = `Sandbox: ghi nhận hoàn một phần ${amtStr}`;
    messageText = `[Điều phối viên] Ghi nhận phương án hoàn sandbox ${amtStr}. Căn cứ: ${dto.reason}`;
    next.checklist = next.checklist.map((c) =>
      c.label.includes('Quyết định') ? { ...c, status: 'Đạt' } : c,
    );
  } else if (dto.remedy === 'full') {
    next.status = 'RESOLVED';
    next.verifyStatus = 'RESOLVED';
    next.resolution = 'FULL_REFUND';
    next.order.refundRequested = next.order.total;
    statusTitle = 'Sandbox: ghi nhận hoàn toàn phần (ledger stub)';
    messageText = `[Điều phối viên] Ghi nhận hoàn toàn phần sandbox. Căn cứ: ${dto.reason}`;
    next.checklist = next.checklist.map((c) =>
      c.label.includes('Quyết định') ? { ...c, status: 'Đạt' } : c,
    );
  } else {
    next.status = 'RESOLVED';
    next.verifyStatus = 'REJECTED';
    next.resolution = 'REJECTED';
    statusTitle = 'Đã giải quyết: Từ chối yêu cầu khiếu nại';
    messageText = `[Điều phối viên] Đã bác bỏ yêu cầu khiếu nại. Căn cứ từ chối: ${dto.reason}`;
    next.checklist = next.checklist.map((c) =>
      c.label.includes('Quyết định') ? { ...c, status: 'Từ chối' } : c,
    );
  }

  next.timeline.push({ at: timeFormatted, title: statusTitle });
  next.messages.push({
    from: 'Điều phối viên DealGo',
    at: timeFormatted,
    body: messageText,
  });
  if (dto.note?.trim()) {
    next.messages.push({
      from: 'Ghi chú nội bộ (Audit)',
      at: timeFormatted,
      body: dto.note.trim(),
      internal: true,
    });
  }
  return next;
}

function buildSeedCase(
  c: Partial<DisputeCaseDetail> & {
    code: string;
    type: string;
    priority: DisputeCaseDetail['priority'];
    status: DisputeCaseDetail['status'];
    orderCode: string;
    reporter: string;
    summary: string;
    assignee: string;
    createdAt: string;
  },
): DisputeCaseDetail {
  return {
    id: randomUUID(),
    code: c.code,
    type: c.type,
    priority: c.priority,
    status: c.status,
    verifyStatus: c.status === 'RESOLVED' ? 'RESOLVED' : 'INVESTIGATING',
    openedAt: c.createdAt,
    orderCode: c.orderCode,
    relatedCode: c.orderCode,
    paymentId: `GD-${c.code.slice(3)}`,
    refundCode: `RF-${c.code.slice(3)}`,
    assignee: c.assignee,
    slaRemaining: '01:58:00',
    reporter: c.reporter,
    summary: c.summary,
    createdAt: c.createdAt,
    parties: [
      {
        role: 'Khách hàng',
        name: c.reporter,
        initials: c.reporter.slice(0, 2).toUpperCase(),
      },
      { role: 'Cửa hàng', name: 'Highlands Coffee', initials: 'HC' },
      { role: 'Tài xế', name: 'Phan Anh Tuấn', initials: 'PA' },
    ],
    timeline: [
      { at: c.createdAt, title: 'Khách tạo khiếu nại' },
      { at: '14:48', title: `Đã phân công ${c.assignee}` },
    ],
    messages: [
      { from: 'Khách hàng', at: c.createdAt, body: c.summary },
      {
        from: 'Hỗ trợ',
        at: '14:50',
        body: 'DealGo đã tiếp nhận. Chúng tôi đang kiểm tra.',
      },
    ],
    order: {
      code: c.orderCode,
      service: 'Đồ ăn',
      result: 'Đã giao thành công',
      payment: 'Ví DealGo',
      total: 120000,
      refundRequested: 65000,
    },
    checklist: [
      { label: 'Xác minh đơn & thanh toán', status: 'Đạt' },
      { label: 'Nhận bằng chứng khách', status: 'Đạt' },
      { label: 'Phản hồi cửa hàng', status: 'Đang chờ' },
      { label: 'Đối chiếu ảnh giao hàng', status: 'Đang chờ' },
      { label: 'Quyết định hoàn / từ chối', status: 'Đang chờ' },
    ],
  };
}

function filterMemory(
  allItems: DisputeCaseDetail[],
  options: {
    q?: string;
    status?: string;
    priority?: string;
    type?: string;
    party?: string;
  },
): DisputeCaseDetail[] {
  let items = allItems;
  if (options.q?.trim()) {
    const q = options.q.trim().toLowerCase();
    items = items.filter(
      (d) =>
        d.code.toLowerCase().includes(q) ||
        d.orderCode.toLowerCase().includes(q) ||
        (d.relatedCode && d.relatedCode.toLowerCase().includes(q)) ||
        d.type.toLowerCase().includes(q) ||
        (d.summary && d.summary.toLowerCase().includes(q)) ||
        (d.reporter && d.reporter.toLowerCase().includes(q)) ||
        d.assignee.toLowerCase().includes(q) ||
        d.parties.some((p) => p.name.toLowerCase().includes(q)),
    );
  }
  if (options.status && options.status !== 'ALL') {
    items = items.filter((d) => d.status === options.status);
  }
  if (options.priority && options.priority !== 'ALL') {
    items = items.filter((d) => d.priority === options.priority);
  }
  if (options.type && options.type !== 'ALL') {
    const t = options.type.toLowerCase();
    items = items.filter((d) => d.type.toLowerCase().includes(t));
  }
  if (options.party && options.party !== 'ALL') {
    const p = options.party.toLowerCase();
    items = items.filter(
      (d) =>
        (d.reporter && d.reporter.toLowerCase().includes(p)) ||
        d.parties.some((party) => party.name.toLowerCase().includes(p)),
    );
  }
  return items;
}

function buildPrismaWhere(options: {
  q?: string;
  status?: string;
  priority?: string;
  type?: string;
  party?: string;
}) {
  const where: Record<string, unknown> = {};
  if (options.status && options.status !== 'ALL') {
    where.status = options.status;
  }
  if (options.priority && options.priority !== 'ALL') {
    where.priority = options.priority;
  }
  if (options.type && options.type !== 'ALL') {
    where.type = { contains: options.type, mode: 'insensitive' };
  }
  if (options.q?.trim()) {
    const q = options.q.trim();
    where.OR = [
      { code: { contains: q, mode: 'insensitive' } },
      { orderCode: { contains: q, mode: 'insensitive' } },
      { type: { contains: q, mode: 'insensitive' } },
      { summary: { contains: q, mode: 'insensitive' } },
      { reporterName: { contains: q, mode: 'insensitive' } },
      { assignee: { contains: q, mode: 'insensitive' } },
    ];
  }
  if (options.party && options.party !== 'ALL') {
    where.reporterName = { contains: options.party, mode: 'insensitive' };
  }
  return where;
}

type PrismaDisputeRow = {
  id: string;
  code: string;
  type: string;
  priority: DisputeCaseDetail['priority'];
  status: DisputeCaseDetail['status'];
  verifyStatus: DisputeCaseDetail['verifyStatus'];
  orderCode: string;
  paymentId: string;
  refundCode: string;
  assignee: string;
  slaRemaining: string;
  reporterName: string;
  summary: string;
  parties: unknown;
  timeline: unknown;
  messages: unknown;
  checklist: unknown;
  orderSnapshot: unknown;
  resolution: DisputeResolution | null;
  openedAt: Date;
  createdAt: Date;
};

function mapPrismaDispute(row: PrismaDisputeRow): DisputeCaseDetail {
  const order = (row.orderSnapshot ?? {}) as DisputeCaseDetail['order'];
  return {
    id: row.id,
    code: row.code,
    type: row.type,
    priority: row.priority,
    status: row.status,
    verifyStatus: row.verifyStatus,
    openedAt: formatOpenedAt(row.openedAt),
    orderCode: row.orderCode,
    relatedCode: row.orderCode,
    paymentId: row.paymentId,
    refundCode: row.refundCode,
    assignee: row.assignee,
    slaRemaining: row.slaRemaining,
    reporter: row.reporterName,
    summary: row.summary,
    createdAt: formatOpenedAt(row.createdAt),
    parties: (row.parties as DisputeParty[]) ?? [],
    timeline: (row.timeline as DisputeTimelineItem[]) ?? [],
    messages: (row.messages as DisputeMessageItem[]) ?? [],
    checklist: (row.checklist as DisputeChecklistItem[]) ?? [],
    order: {
      code: order.code ?? row.orderCode,
      service: order.service ?? 'Đồ ăn',
      result: order.result ?? '',
      payment: order.payment ?? '',
      total: order.total ?? 0,
      refundRequested: order.refundRequested ?? 0,
    },
    resolution: row.resolution,
  };
}

function formatOpenedAt(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)} · ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

type RefundTx = {
  ledgerAccount: {
    findMany: (args: {
      where: { code: { in: string[] } };
    }) => Promise<Array<{ id: string; code: string }>>;
    create: (args: {
      data: { id: string; code: string; name: string; kind: 'ASSET' | 'LIABILITY' };
    }) => Promise<{ id: string; code: string }>;
  };
  ledgerJournal: {
    findUnique: (args: {
      where: {
        entityType_entityId_event: {
          entityType: 'DISPUTE';
          entityId: string;
          event: 'SANDBOX_REFUND_RECORDED';
        };
      };
    }) => Promise<{ id: string } | null>;
    create: (args: {
      data: {
        entityType: 'DISPUTE';
        entityId: string;
        event: 'SANDBOX_REFUND_RECORDED';
        status: 'POSTED';
        currency: string;
        amountVnd: number;
        entries: {
          create: Array<{
            accountId: string;
            direction: 'DEBIT' | 'CREDIT';
            amountVnd: number;
          }>;
        };
      };
    }) => Promise<{ id: string }>;
  };
  refundRequest: {
    create: (args: {
      data: {
        id: string;
        code: string;
        disputeId: string;
        kind: 'PARTIAL' | 'FULL';
        status: 'SANDBOX_RECORDED';
        amountVnd: number;
        reason: string;
        ledgerJournalId: string | null;
        createdByUserId: string;
      };
    }) => Promise<{ id: string }>;
  };
  disputeCase: {
    update: (args: {
      where: { id: string };
      data: Record<string, unknown>;
    }) => Promise<PrismaDisputeRow>;
  };
  opsAuditLog: {
    create: (args: { data: Record<string, unknown> }) => Promise<{ id: string }>;
  };
};

async function postSandboxRefundJournal(
  tx: RefundTx,
  input: { disputeId: string; amountVnd: number },
): Promise<string> {
  const existing = await tx.ledgerJournal.findUnique({
    where: {
      entityType_entityId_event: {
        entityType: 'DISPUTE',
        entityId: input.disputeId,
        event: 'SANDBOX_REFUND_RECORDED',
      },
    },
  });
  if (existing) {
    return existing.id;
  }

  let accounts = await tx.ledgerAccount.findMany({
    where: { code: { in: [LEDGER_REFUND_PAYABLE, LEDGER_REFUND_CLEARING] } },
  });
  const byCode = new Map(accounts.map((a) => [a.code, a]));
  if (!byCode.has(LEDGER_REFUND_PAYABLE)) {
    const created = await tx.ledgerAccount.create({
      data: {
        id: randomUUID(),
        code: LEDGER_REFUND_PAYABLE,
        name: 'Sandbox refund payable (ops stub)',
        kind: 'LIABILITY',
      },
    });
    byCode.set(created.code, created);
  }
  if (!byCode.has(LEDGER_REFUND_CLEARING)) {
    const created = await tx.ledgerAccount.create({
      data: {
        id: randomUUID(),
        code: LEDGER_REFUND_CLEARING,
        name: 'Sandbox refund clearing (ops stub)',
        kind: 'ASSET',
      },
    });
    byCode.set(created.code, created);
  }

  const journal = await tx.ledgerJournal.create({
    data: {
      entityType: 'DISPUTE',
      entityId: input.disputeId,
      event: 'SANDBOX_REFUND_RECORDED',
      status: 'POSTED',
      currency: 'VND',
      amountVnd: input.amountVnd,
      entries: {
        create: [
          {
            accountId: byCode.get(LEDGER_REFUND_CLEARING)!.id,
            direction: 'DEBIT',
            amountVnd: input.amountVnd,
          },
          {
            accountId: byCode.get(LEDGER_REFUND_PAYABLE)!.id,
            direction: 'CREDIT',
            amountVnd: input.amountVnd,
          },
        ],
      },
    },
  });
  return journal.id;
}
