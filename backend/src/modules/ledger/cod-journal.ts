import {
  LEDGER_CASH_IN_TRANSIT_CODE,
  LEDGER_COD_OBLIGATION_CODE,
  LEDGER_FEE_DRIVER_RECEIVABLE_CODE,
  LEDGER_FEE_REVENUE_CODE,
  LEDGER_PROMO_DRIVER_PAYABLE_CODE,
  LEDGER_PROMO_EXPENSE_CODE,
  LEDGER_PROMO_MERCHANT_PAYABLE_CODE,
  type LedgerEntityTypeName,
  type LedgerEntryDirectionName,
} from './ledger.constants.js';
import { LedgerRuleError } from './ledger.error.js';

export type CodJournalLine = {
  accountCode: string;
  direction: LedgerEntryDirectionName;
  amountVnd: number;
};

/**
 * Sandbox COD obligation: driver holds cash (asset) against platform clearing (liability).
 * No PSP capture — POSTED journals only.
 */
export function buildCodObligationLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    {
      accountCode: LEDGER_CASH_IN_TRANSIT_CODE,
      direction: 'DEBIT',
      amountVnd,
    },
    {
      accountCode: LEDGER_COD_OBLIGATION_CODE,
      direction: 'CREDIT',
      amountVnd,
    },
  ];
}

/**
 * DealGo funds a voucher: the customer pays the net COD total, so the platform records
 * the discount as its own expense and owes the same amount to whoever was short-paid:
 * the merchant for food, the driver for a ride (DEC-PROD-024).
 */
export function buildPromotionDiscountLines(
  amountVnd: number,
  entityType: LedgerEntityTypeName = 'FOOD_ORDER',
): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  const payable =
    entityType === 'RIDE' ? LEDGER_PROMO_DRIVER_PAYABLE_CODE : LEDGER_PROMO_MERCHANT_PAYABLE_CODE;
  return [
    { accountCode: LEDGER_PROMO_EXPENSE_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: payable, direction: 'CREDIT', amountVnd },
  ];
}

/**
 * Platform fee on a COD job: the driver collected the whole fare in cash, so the fee is
 * owed by the driver to DealGo (receivable) and recognised as platform revenue.
 */
export function buildDriverPlatformFeeLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    { accountCode: LEDGER_FEE_DRIVER_RECEIVABLE_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: LEDGER_FEE_REVENUE_CODE, direction: 'CREDIT', amountVnd },
  ];
}

/** Ledger events that can be posted for a completed job, with their line builders. */
export type PostableLedgerEvent =
  | 'COD_OBLIGATION_POSTED'
  | 'PROMOTION_DISCOUNT_FUNDED'
  | 'DRIVER_PLATFORM_FEE_ACCRUED';

export type LedgerLineBuilder = (
  amountVnd: number,
  entityType?: LedgerEntityTypeName,
) => CodJournalLine[];

export const LEDGER_LINE_BUILDERS: Readonly<Record<PostableLedgerEvent, LedgerLineBuilder>> = {
  COD_OBLIGATION_POSTED: buildCodObligationLines,
  PROMOTION_DISCOUNT_FUNDED: buildPromotionDiscountLines,
  DRIVER_PLATFORM_FEE_ACCRUED: buildDriverPlatformFeeLines,
};

export function assertBalancedLines(lines: CodJournalLine[]): void {
  let debit = 0;
  let credit = 0;
  for (const line of lines) {
    if (!Number.isSafeInteger(line.amountVnd) || line.amountVnd <= 0) {
      throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
    }
    if (line.direction === 'DEBIT') {
      debit += line.amountVnd;
    } else {
      credit += line.amountVnd;
    }
  }
  if (debit !== credit) {
    throw new LedgerRuleError('LEDGER_UNBALANCED');
  }
}
