import { Injectable } from '@nestjs/common';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../shared/pagination/pagination.js';
import {
  OpsDisputesService,
  type DisputeCaseDetail,
  type DisputeResolution,
} from '../support/ops-disputes.service.js';

export type OpsRefundStatus =
  | 'AWAITING_REVIEW'
  | 'NEEDS_MORE_INFO'
  | 'PROCESSING'
  | 'REFUNDED'
  | 'REJECTED'
  | 'EVIDENCE_REQUESTED';

export type OpsRefundItem = {
  code: string;
  orderCode: string;
  customer: string;
  amount: number;
  reason: string;
  service: string;
  status: OpsRefundStatus;
  createdAt: string;
  paymentId: string;
  originalAmount: number;
  assignee: string;
  disputeCode: string;
  resolution: DisputeResolution | null;
  summary: string | null;
};

@Injectable()
export class OpsRefundsService {
  constructor(private readonly disputes: OpsDisputesService) {}

  async list(options: {
    page?: number;
    limit?: number;
    q?: string;
    status?: string;
  }): Promise<PageResult<OpsRefundItem>> {
    const safePage = normalizePage(options.page);
    const safeLimit = normalizeLimit(options.limit);

    const source = await this.disputes.list({ page: 1, limit: 500 });
    let items = source.items
      .filter(isRefundRelatedDispute)
      .map(toRefundItem);

    if (options.status && options.status !== 'ALL') {
      items = items.filter((item) => item.status === options.status);
    }

    if (options.q?.trim()) {
      const q = options.q.trim().toLowerCase();
      items = items.filter(
        (item) =>
          item.code.toLowerCase().includes(q) ||
          item.orderCode.toLowerCase().includes(q) ||
          item.customer.toLowerCase().includes(q) ||
          item.reason.toLowerCase().includes(q) ||
          item.disputeCode.toLowerCase().includes(q) ||
          item.assignee.toLowerCase().includes(q) ||
          (item.summary !== null && item.summary.toLowerCase().includes(q)),
      );
    }

    const total = items.length;
    const start = (safePage - 1) * safeLimit;
    return {
      items: items.slice(start, start + safeLimit),
      page: safePage,
      limit: safeLimit,
      total,
    };
  }
}

export function isRefundRelatedDispute(dispute: DisputeCaseDetail): boolean {
  if (
    dispute.resolution === 'PARTIAL_REFUND' ||
    dispute.resolution === 'FULL_REFUND'
  ) {
    return true;
  }

  const blob = [
    dispute.type,
    dispute.summary ?? '',
    ...dispute.timeline.map((t) => t.title),
  ]
    .join(' ')
    .toLowerCase();

  if (blob.includes('hoàn') || blob.includes('refund')) {
    return true;
  }

  return dispute.order.refundRequested > 0 && dispute.status !== 'RESOLVED';
}

export function toRefundItem(dispute: DisputeCaseDetail): OpsRefundItem {
  return {
    code: dispute.refundCode,
    orderCode: dispute.orderCode,
    customer: dispute.reporter ?? dispute.parties[0]?.name ?? 'Khách hàng',
    amount: dispute.order.refundRequested,
    reason: dispute.type,
    service: dispute.order.service,
    status: mapRefundStatus(dispute),
    createdAt: dispute.openedAt || dispute.createdAt || '',
    paymentId: dispute.paymentId,
    originalAmount: dispute.order.total,
    assignee: dispute.assignee,
    disputeCode: dispute.code,
    resolution: dispute.resolution ?? null,
    summary: dispute.summary ?? null,
  };
}

function mapRefundStatus(dispute: DisputeCaseDetail): OpsRefundStatus {
  if (dispute.resolution === 'PARTIAL_REFUND' || dispute.resolution === 'FULL_REFUND') {
    return 'REFUNDED';
  }
  if (dispute.resolution === 'REJECTED' || dispute.verifyStatus === 'REJECTED') {
    return 'REJECTED';
  }
  if (
    dispute.resolution === 'EVIDENCE_REQUESTED' ||
    dispute.status === 'AWAITING_RESPONSE'
  ) {
    return 'EVIDENCE_REQUESTED';
  }
  if (dispute.status === 'INVESTIGATING') {
    return 'PROCESSING';
  }
  if (dispute.status === 'PENDING') {
    return 'NEEDS_MORE_INFO';
  }
  if (dispute.status === 'RESOLVED') {
    return dispute.verifyStatus === 'RESOLVED' ? 'REFUNDED' : 'REJECTED';
  }
  return 'AWAITING_REVIEW';
}
