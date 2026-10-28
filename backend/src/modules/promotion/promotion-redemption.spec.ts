import { describe, expect, it } from 'vitest';
import { evaluateVoucher, percentVoucherDiscountVnd } from './promotion-redemption.js';

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

  it('rounds percentage discounts down to 1.000đ for food and ride', () => {
    // 10% of 58.036đ = 5.803,6đ → 5.000đ; the cash due keeps the order's own rounding.
    const food = evaluateVoucher(base, { serviceType: 'FOOD', orderAmount: 58_036 }, 0, now);
    expect(food).toEqual({ ok: true, discountVnd: 5_000, finalAmount: 53_036 });
    // A round ride fare stays round: 15% of 59.000đ = 8.850đ → 8.000đ, cash 51.000đ.
    const ride = evaluateVoucher(
      { ...base, serviceType: 'RIDE', discountValue: 15 },
      { serviceType: 'RIDE', orderAmount: 59_000 },
      0,
      now,
    );
    expect(ride).toEqual({ ok: true, discountVnd: 8_000, finalAmount: 51_000 });
  });

  it('rounds an odd cap down too, and keeps the minimum order rule', () => {
    const capped = evaluateVoucher(
      { ...base, maxDiscountAmount: 15_500 },
      { serviceType: 'FOOD', orderAmount: 300_000 },
      0,
      now,
    );
    expect(capped).toMatchObject({ ok: true, discountVnd: 15_000, finalAmount: 285_000 });
    const belowMin = evaluateVoucher(
      { ...base, minOrderAmount: 60_000 },
      { serviceType: 'FOOD', orderAmount: 59_000 },
      0,
      now,
    );
    expect(belowMin).toMatchObject({ ok: false, code: 'VOUCHER_MIN_ORDER' });
  });

  it('rejects a percentage voucher that would take off less than 1.000đ', () => {
    const v = evaluateVoucher(base, { serviceType: 'FOOD', orderAmount: 9_000 }, 0, now);
    expect(v).toMatchObject({ ok: false, code: 'VOUCHER_MIN_ORDER' });
  });

  it('leaves fixed-amount discounts as configured', () => {
    const v = evaluateVoucher(
      { ...base, discountType: 'FIXED_AMOUNT', discountValue: 15_000 },
      { serviceType: 'FOOD', orderAmount: 58_036 },
      0,
      now,
    );
    expect(v).toEqual({ ok: true, discountVnd: 15_000, finalAmount: 43_036 });
  });
});

describe('percentVoucherDiscountVnd', () => {
  it.each([
    [58_036, 10, undefined, 5_000],
    [59_000, 10, undefined, 5_000],
    [60_000, 10, undefined, 6_000],
    [300_000, 20, 40_000, 40_000],
    [300_000, 10, 15_500, 15_000],
    [9_999, 10, null, 0],
    [-5, 10, null, 0],
  ])('%i × %i%% cap %s → %i', (amount, percent, cap, expected) => {
    expect(percentVoucherDiscountVnd(amount, percent, cap)).toBe(expected);
  });
});
