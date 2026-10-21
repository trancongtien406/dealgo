import type { PromotionSponsor } from './promotion.types.js';

/**
 * DealGo's part of a voucher discount (DEC-PROD-015). PLATFORM: all of it; MERCHANT: none (the
 * merchant is simply owed subtotal − discount); SHARED: `sharedPlatformPercent` of it, rounded
 * half-up to whole VND. A missing sponsor (orders placed before the snapshot existed) counts as
 * PLATFORM, matching DEC-PROD-009.
 */
export function platformFundedDiscountVnd(
  discountVnd: number,
  sponsor: PromotionSponsor | null,
  sharedPlatformPercent: number,
): number {
  if (discountVnd <= 0 || sponsor === 'MERCHANT') {
    return 0;
  }
  if (sponsor === 'SHARED') {
    if (!Number.isFinite(sharedPlatformPercent) || sharedPlatformPercent < 0 || sharedPlatformPercent > 100) {
      throw new RangeError(`Shared voucher percent out of range: ${sharedPlatformPercent}`);
    }
    return Math.round((discountVnd * Math.round(sharedPlatformPercent * 100)) / 10_000);
  }
  return discountVnd;
}
