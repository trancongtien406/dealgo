import { describe, expect, it } from 'vitest';
import { buildPromotionDiscountLines } from './cod-journal.js';
import {
  LEDGER_PROMO_EXPENSE_CODE,
  LEDGER_PROMO_MERCHANT_PAYABLE_CODE,
} from './ledger.constants.js';
import { MemoryLedgerRepository } from './ledger.repository.js';

describe('DealGo-funded voucher discount journal', () => {
  it('debits platform expense and credits the merchant payable', () => {
    expect(buildPromotionDiscountLines(20_000)).toEqual([
      { accountCode: LEDGER_PROMO_EXPENSE_CODE, direction: 'DEBIT', amountVnd: 20_000 },
      { accountCode: LEDGER_PROMO_MERCHANT_PAYABLE_CODE, direction: 'CREDIT', amountVnd: 20_000 },
    ]);
    expect(() => buildPromotionDiscountLines(0)).toThrow();
  });

  it('posts once per order next to the COD obligation', async () => {
    const ledger = new MemoryLedgerRepository();
    const order = { entityType: 'FOOD_ORDER' as const, entityId: 'order-1' };
    const cod = await ledger.postCodObligation({ ...order, amountVnd: 45_000 });
    const first = await ledger.postPromotionDiscount({ ...order, amountVnd: 20_000 });
    const replay = await ledger.postPromotionDiscount({ ...order, amountVnd: 20_000 });
    expect(replay.id).toBe(first.id);
    expect(first.event).toBe('PROMOTION_DISCOUNT_FUNDED');
    expect(cod.amountVnd).toBe(45_000);
    expect(
      (await ledger.findByEntity('FOOD_ORDER', 'order-1', 'PROMOTION_DISCOUNT_FUNDED'))?.amountVnd,
    ).toBe(20_000);
  });
});
