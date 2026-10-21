import { describe, expect, it } from 'vitest';
import { evaluateVoucher } from './promotion-redemption.js';

const base = {
  code: 'X',
  status: 'ACTIVE' as const,
  startDate: '2026-01-01T00:00:00.000Z',
  endDate: '2027-01-01T00:00:00.000Z',
  serviceType: 'ALL' as const,
  minOrderAmount: 0,
  usedCount: 0,
  usageLimit: 10,
  usedBudget: 0,
  totalBudget: 1_000_000,
  userLimit: 1,
  discountType: 'PERCENTAGE' as const,
  discountValue: 10,
  maxDiscountAmount: 15_000,
};
const now = new Date('2026-10-19T00:00:00.000Z');

describe('evaluateVoucher', () => {
  it('caps percentage discounts', () => {
    const v = evaluateVoucher(base, { serviceType: 'FOOD', orderAmount: 300_000 }, 0, now);
    expect(v).toEqual({ ok: true, discountVnd: 15_000, finalAmount: 285_000 });
  });

  it('limits delivery discounts to the delivery fee', () => {
    const v = evaluateVoucher(
      { ...base, discountType: 'DELIVERY_DISCOUNT', discountValue: 30_000 },
      { serviceType: 'FOOD', orderAmount: 50_000, deliveryFee: 12_000 },
      0,
      now,
    );
    expect(v).toMatchObject({ ok: true, discountVnd: 12_000 });
  });

  it.each([
    [{ status: 'PAUSED' as const }, 0, 'VOUCHER_PAUSED'],
    [{ status: 'ENDED' as const }, 0, 'VOUCHER_INACTIVE'],
    [{ startDate: '2026-12-01T00:00:00.000Z' }, 0, 'VOUCHER_NOT_STARTED'],
    [{ endDate: '2026-10-01T00:00:00.000Z' }, 0, 'VOUCHER_EXPIRED'],
    [{ serviceType: 'RIDE' as const }, 0, 'VOUCHER_WRONG_SERVICE'],
    [{ minOrderAmount: 999_999 }, 0, 'VOUCHER_MIN_ORDER'],
    [{ usedCount: 10 }, 0, 'VOUCHER_USAGE_EXHAUSTED'],
    [{}, 1, 'VOUCHER_USER_LIMIT'],
    [{ usedBudget: 995_000 }, 0, 'VOUCHER_BUDGET_EXHAUSTED'],
  ])('rejects %o', (overrides, used, code) => {
    const v = evaluateVoucher(
      { ...base, ...overrides },
      { serviceType: 'FOOD', orderAmount: 100_000 },
      used,
      now,
    );
    expect(v).toMatchObject({ ok: false, code });
  });
});
