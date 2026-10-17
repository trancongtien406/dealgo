import { NotFoundException } from '@nestjs/common';
import { beforeEach, describe, expect, it } from 'vitest';
import { OpsAuditLogsService } from '../operations/ops-audit-logs.service.js';
import { OpsDisputesService } from './ops-disputes.service.js';

describe('OpsDisputesService', () => {
  let disputes: OpsDisputesService;

  beforeEach(() => {
    disputes = new OpsDisputesService(
      { db: () => null } as never,
      new OpsAuditLogsService({ db: () => null } as never),
    );
  });

  it('returns 404 for unknown dispute codes (no synthesis)', async () => {
    await expect(disputes.getByCode('KN-DOES-NOT-EXIST')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('resolves evidence without claiming money movement', async () => {
    const result = await disputes.resolve(
      'KN-240610-0245',
      { remedy: 'evidence', reason: 'Cần ảnh biên nhận giao hàng' },
      'actor-1',
    );
    expect(result.success).toBe(true);
    expect(result.dispute.resolution).toBe('EVIDENCE_REQUESTED');
    expect(result.refundSandbox).toBeUndefined();
    expect(result.message).not.toMatch(/PSP/i);
  });

  it('records partial refund as sandbox stub, not PSP success', async () => {
    const result = await disputes.resolve(
      'KN-240610-0245',
      { remedy: 'partial', reason: 'Thiếu topping', amount: 35_000 },
      'actor-1',
    );
    expect(result.success).toBe(true);
    expect(result.dispute.resolution).toBe('PARTIAL_REFUND');
    expect(result.refundSandbox).toBe(true);
    expect(result.message).toMatch(/sandbox/i);
    expect(result.message).not.toMatch(/đã hoàn tiền thành công qua cổng/i);
  });

  it('records full refund as sandbox stub', async () => {
    const result = await disputes.resolve(
      'KN-240610-0241',
      { remedy: 'full', reason: 'Hoàn toàn phần theo chính sách sandbox' },
      'actor-1',
    );
    expect(result.refundSandbox).toBe(true);
    expect(result.dispute.resolution).toBe('FULL_REFUND');
  });
});
