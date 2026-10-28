import { describe, expect, it } from 'vitest';
import { MemoryPromotionRepository } from './promotion.repository.js';
import { PromotionService, type MerchantOfferInput } from './promotion.service.js';

const STORE = '00000000-0000-4000-8000-0000000000a1';
const OTHER = '00000000-0000-4000-8000-0000000000b2';
const NOW = new Date();
const DAY = 86_400_000;
const iso = (offsetMs: number) => new Date(NOW.getTime() + offsetMs).toISOString();

function offer(overrides: Partial<MerchantOfferInput> = {}): MerchantOfferInput {
  return {
    name: 'Giảm 20% món mới',
    discountType: 'PERCENTAGE',
    discountValue: 20,
    maxDiscountAmount: 30000,
    minOrderAmount: 80000,
    usageLimit: 100,
    userLimit: 1,
    startDate: iso(-60_000),
    endDate: iso(30 * DAY),
    ...overrides,
  };
}

function setup() {
  const repository = new MemoryPromotionRepository([]);
  return { repository, service: new PromotionService(repository) };
}

describe('store offers', () => {
  it('creates a merchant-funded FOOD offer with a generated code', async () => {
    const { service } = setup();
    const created = await service.createStoreOffer(STORE, offer(), NOW);
    expect(created).toMatchObject({
      storeId: STORE,
      serviceType: 'FOOD',
      sponsor: 'MERCHANT',
      status: 'ACTIVE',
      totalBudget: 3_000_000,
    });
    expect(created.code).toMatch(/^CH[A-Z0-9]{6}$/);
  });

  it.each([
    [{ discountValue: 0 }, 'PROMOTION_VALUE_INVALID'],
    [{ maxDiscountAmount: undefined }, 'PROMOTION_CAP_REQUIRED'],
    [{ discountType: 'FIXED_AMOUNT' as const, discountValue: 500 }, 'PROMOTION_VALUE_INVALID'],
    [{ discountType: 'FIXED_AMOUNT' as const, discountValue: 50000, minOrderAmount: 30000 }, 'PROMOTION_MIN_ORDER_INVALID'],
    [{ endDate: iso(-DAY) }, 'PROMOTION_DATES_INVALID'],
    [{ endDate: iso(400 * DAY) }, 'PROMOTION_DATES_INVALID'],
  ])('rejects invalid input %o', async (overrides, errorCode) => {
    const { service } = setup();
    await expect(service.createStoreOffer(STORE, offer(overrides), NOW)).rejects.toMatchObject({
      response: { errorCode },
    });
  });

  it('applies only at its own store', async () => {
    const { service } = setup();
    const created = await service.createStoreOffer(STORE, offer({ code: 'quan20' }), NOW);
    expect(created.code).toBe('QUAN20');
    const here = await service.validateAndCalculate({
      voucherCode: 'QUAN20',
      serviceType: 'FOOD',
      orderAmount: 200000,
      customerId: 'cust-1',
      storeId: STORE,
    });
    expect(here).toMatchObject({ valid: true, discountAmount: 30000 });
    const elsewhere = await service.validateAndCalculate({
      voucherCode: 'QUAN20',
      serviceType: 'FOOD',
      orderAmount: 200000,
      customerId: 'cust-1',
      storeId: OTHER,
    });
    expect(elsewhere).toMatchObject({ valid: false, rejectCode: 'VOUCHER_WRONG_STORE' });
  });

  it('shows live offers on store cards, best first, and hides paused ones', async () => {
    const { service } = setup();
    const small = await service.createStoreOffer(
      STORE,
      offer({ discountType: 'FIXED_AMOUNT', discountValue: 10000, maxDiscountAmount: undefined, minOrderAmount: 50000 }),
      NOW,
    );
    await service.createStoreOffer(STORE, offer(), NOW);
    const cards = await service.storeOffers([STORE, OTHER], 3, NOW);
    expect(cards.get(STORE)?.map((o) => o.discountType)).toEqual(['PERCENTAGE', 'FIXED_AMOUNT']);
    expect(cards.has(OTHER)).toBe(false);

    await service.setStoreOfferStatus(STORE, small.id, 'PAUSED');
    expect((await service.storeOffers([STORE], 3, NOW)).get(STORE)).toHaveLength(1);
  });

  it('keeps store offers out of the platform voucher list but in the store list', async () => {
    const { service } = setup();
    const created = await service.createStoreOffer(STORE, offer(), NOW);
    const platform = await service.listAvailableForCustomer('cust-1', 'FOOD', undefined, NOW);
    expect(platform.some((v) => v.code === created.code)).toBe(false);
    const inStore = await service.listAvailableForCustomer('cust-1', 'FOOD', STORE, NOW);
    expect(inStore.some((v) => v.code === created.code)).toBe(true);
  });

  it('will not touch another store offer or reopen an ended one', async () => {
    const { service } = setup();
    const created = await service.createStoreOffer(STORE, offer(), NOW);
    await expect(service.setStoreOfferStatus(OTHER, created.id, 'PAUSED')).rejects.toMatchObject({ status: 404 });
    await service.setStoreOfferStatus(STORE, created.id, 'ENDED');
    await expect(service.setStoreOfferStatus(STORE, created.id, 'ACTIVE')).rejects.toMatchObject({ status: 409 });
  });

  it('caps live offers per store', async () => {
    const { service } = setup();
    for (let i = 0; i < 10; i += 1) {
      await service.createStoreOffer(STORE, offer(), NOW);
    }
    await expect(service.createStoreOffer(STORE, offer(), NOW)).rejects.toMatchObject({
      response: { errorCode: 'PROMOTION_STORE_LIMIT' },
    });
  });
});
