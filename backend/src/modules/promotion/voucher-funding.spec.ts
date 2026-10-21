import { describe, expect, it } from 'vitest';
import { platformFundedDiscountVnd } from './voucher-funding.js';

describe('platformFundedDiscountVnd', () => {
  it('splits the discount by sponsor', () => {
    expect(platformFundedDiscountVnd(20_000, 'PLATFORM', 30)).toBe(20_000);
    expect(platformFundedDiscountVnd(20_000, null, 30)).toBe(20_000);
    expect(platformFundedDiscountVnd(20_000, 'MERCHANT', 30)).toBe(0);
    expect(platformFundedDiscountVnd(20_000, 'SHARED', 30)).toBe(6000);
    expect(platformFundedDiscountVnd(15_005, 'SHARED', 50)).toBe(7503);
    expect(platformFundedDiscountVnd(20_000, 'SHARED', 100)).toBe(20_000);
    expect(platformFundedDiscountVnd(0, 'PLATFORM', 100)).toBe(0);
    expect(() => platformFundedDiscountVnd(10_000, 'SHARED', 120)).toThrow(RangeError);
  });
});
