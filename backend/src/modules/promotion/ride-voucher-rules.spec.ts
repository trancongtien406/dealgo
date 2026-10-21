import { describe, expect, it } from 'vitest';
import { buildPromotionDiscountLines } from '../ledger/cod-journal.js';
import { evaluateVoucher } from './promotion-redemption.js';
import { MemoryPromotionRepository } from './promotion.repository.js';
import { PromotionService } from './promotion.service.js';
import type { PromotionCampaign } from './promotion.types.js';

function campaign(overrides: Partial<PromotionCampaign> = {}): PromotionCampaign {
  const now = Date.now();
  return {
    id: 'p1',
    code: 'ALL10',
    name: 'ALL10',
    description: 'd',
    serviceType: 'ALL',
    discountType: 'FIXED_AMOUNT',
    discountValue: 10_000,
    minOrderAmount: 0,
    totalBudget: 1_000_000,
    usedBudget: 0,
    usageLimit: 10,
    usedCount: 0,
    userLimit: 1,
    targetAudience: 'ALL',
    status: 'ACTIVE',
    startDate: new Date(now - 60_000).toISOString(),
    endDate: new Date(now + 60_000).toISOString(),
    sponsor: 'PLATFORM',
    createdAt: new Date(now).toISOString(),
    updatedAt: new Date(now).toISOString(),
    ...overrides,
  };
}

describe('ride voucher rules (DEC-PROD-024)', () => {
  it('lets a merchant/shared-funded ALL campaign discount food but not a ride', () => {
    for (const sponsor of ['MERCHANT', 'SHARED'] as const) {
      const c = campaign({ sponsor });
      expect(evaluateVoucher(c, { serviceType: 'FOOD', orderAmount: 50_000 }, 0).ok).toBe(true);
      expect(evaluateVoucher(c, { serviceType: 'RIDE', orderAmount: 50_000 }, 0)).toMatchObject({
        ok: false,
        code: 'VOUCHER_WRONG_SERVICE',
      });
    }
    expect(
      evaluateVoucher(campaign(), { serviceType: 'RIDE', orderAmount: 50_000 }, 0),
    ).toMatchObject({ ok: true, discountVnd: 10_000, finalAmount: 40_000 });
  });

  it('never applies a delivery discount to a ride', () => {
    const c = campaign({ discountType: 'DELIVERY_DISCOUNT' });
    expect(evaluateVoucher(c, { serviceType: 'RIDE', orderAmount: 50_000 }, 0)).toMatchObject({
      ok: false,
      code: 'VOUCHER_WRONG_SERVICE',
    });
  });

  it('refuses to create a ride campaign that DealGo does not fund', async () => {
    const service = new PromotionService(new MemoryPromotionRepository([]));
    const base = {
      code: 'RIDESHARE',
      name: 'n',
      description: 'd',
      serviceType: 'RIDE' as const,
      discountType: 'FIXED_AMOUNT' as const,
      discountValue: 5_000,
      minOrderAmount: 0,
      totalBudget: 100_000,
      usageLimit: 10,
      startDate: new Date(Date.now() - 1000).toISOString(),
      endDate: new Date(Date.now() + 60_000).toISOString(),
    };
    await expect(service.create({ ...base, sponsor: 'SHARED' })).rejects.toThrow(/DealGo/);
    await expect(
      service.create({ ...base, discountType: 'DELIVERY_DISCOUNT' }),
    ).rejects.toThrow();
    await expect(service.create(base)).resolves.toMatchObject({ sponsor: 'PLATFORM' });
  });

  it('lists only DealGo-funded, non-delivery campaigns for rides', async () => {
    const service = new PromotionService(
      new MemoryPromotionRepository([
        campaign({ id: 'a', code: 'PLAT' }),
        campaign({ id: 'b', code: 'SHARED', sponsor: 'SHARED' }),
        campaign({ id: 'c', code: 'SHIP', discountType: 'DELIVERY_DISCOUNT' }),
      ]),
    );
    const ride = await service.listAvailableForCustomer('u1', 'RIDE');
    expect(ride.map((v) => v.code)).toEqual(['PLAT']);
    const food = await service.listAvailableForCustomer('u1', 'FOOD');
    expect(food.map((v) => v.code).sort()).toEqual(['PLAT', 'SHARED', 'SHIP']);
  });

  it('owes a ride discount to the driver and a food discount to the merchant', () => {
    expect(buildPromotionDiscountLines(5_000, 'RIDE')[1].accountCode).toBe(
      'sandbox.promo.driver_payable',
    );
    expect(buildPromotionDiscountLines(5_000, 'FOOD_ORDER')[1].accountCode).toBe(
      'sandbox.promo.merchant_payable',
    );
    expect(buildPromotionDiscountLines(5_000)[1].accountCode).toBe('sandbox.promo.merchant_payable');
  });
});
