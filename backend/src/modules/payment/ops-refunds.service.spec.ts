import { beforeEach, describe, expect, it } from 'vitest';
import { OpsAuditLogsService } from '../operations/ops-audit-logs.service.js';
import { OpsDisputesService } from '../support/ops-disputes.service.js';
import {
  isRefundRelatedDispute,
  OpsRefundsService,
  toRefundItem,
} from './ops-refunds.service.js';

describe('OpsRefundsService', () => {
  let disputes: OpsDisputesService;
  let refunds: OpsRefundsService;

  beforeEach(() => {
    disputes = new OpsDisputesService(
      { db: () => null } as never,
      new OpsAuditLogsService({ db: () => null } as never),
    );
    refunds = new OpsRefundsService(disputes);
  });

  it('lists refund-related disputes with pagination', async () => {
    const page = await refunds.list({ page: 1, limit: 10 });
    expect(page.total).toBeGreaterThan(0);
    expect(page.items.every((item) => item.code.startsWith('RF-'))).toBe(true);
    expect(page.items[0]).toEqual(
      expect.objectContaining({
        orderCode: expect.any(String),
        customer: expect.any(String),
        amount: expect.any(Number),
        status: expect.any(String),
        disputeCode: expect.any(String),
      }),
    );
  });

  it('filters by q and status', async () => {
    const byQ = await refunds.list({ q: 'hoàn', page: 1, limit: 20 });
    expect(byQ.total).toBeGreaterThan(0);

    await disputes.resolve(
      'KN-240610-0245',
      { remedy: 'partial', reason: 'Thiếu topping — hoàn một phần', amount: 35_000 },
      'actor-1',
    );

    const refunded = await refunds.list({ status: 'REFUNDED', page: 1, limit: 20 });
    expect(refunded.items.some((i) => i.disputeCode === 'KN-240610-0245')).toBe(true);
    expect(refunded.items.find((i) => i.disputeCode === 'KN-240610-0245')?.resolution).toBe(
      'PARTIAL_REFUND',
    );
  });

  it('maps dispute fields onto refund row shape', async () => {
    const detail = await disputes.getByCode('KN-240610-0245');
    const row = toRefundItem(detail);
    expect(row.code).toBe(detail.refundCode);
    expect(row.amount).toBe(detail.order.refundRequested);
    expect(isRefundRelatedDispute(detail)).toBe(true);
  });

  it('includes FULL_REFUND resolutions', async () => {
    await disputes.resolve(
      'KN-240610-0241',
      { remedy: 'full', reason: 'Hoàn toàn phần theo chính sách' },
      'actor-1',
    );
    const page = await refunds.list({ status: 'REFUNDED', page: 1, limit: 50 });
    const hit = page.items.find((i) => i.disputeCode === 'KN-240610-0241');
    expect(hit?.resolution).toBe('FULL_REFUND');
  });
});
