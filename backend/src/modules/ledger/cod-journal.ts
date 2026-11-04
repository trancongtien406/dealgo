import {
  LEDGER_CASH_IN_TRANSIT_CODE,
  LEDGER_COD_OBLIGATION_CODE,
  LEDGER_FEE_DRIVER_RECEIVABLE_CODE,
  LEDGER_FEE_REVENUE_CODE,
  LEDGER_COMMISSION_MERCHANT_RECEIVABLE_CODE,
  LEDGER_COMMISSION_REVENUE_CODE,
  LEDGER_PROMO_DRIVER_PAYABLE_CODE,
  LEDGER_PROMO_EXPENSE_CODE,
  LEDGER_PROMO_MERCHANT_PAYABLE_CODE,
  LEDGER_PSP_CLEARING_CODE,
  LEDGER_PSP_CUSTOMER_PREPAID_CODE,
  LEDGER_PSP_PAYOUT_PAYABLE_CODE,
  LEDGER_PSP_REFUND_EXPENSE_CODE,
  LEDGER_DRIVER_CREDIT_LIABILITY_CODE,
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

/** Merchant commission on a delivered food order (receivable vs revenue). */
export function buildMerchantCommissionLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    { accountCode: LEDGER_COMMISSION_MERCHANT_RECEIVABLE_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: LEDGER_COMMISSION_REVENUE_CODE, direction: 'CREDIT', amountVnd },
  ];
}

/** Verified online capture: PSP owes DealGo (asset) against the customer's prepayment (liability). */
export function buildPspCaptureLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    { accountCode: LEDGER_PSP_CLEARING_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: LEDGER_PSP_CUSTOMER_PREPAID_CODE, direction: 'CREDIT', amountVnd },
  ];
}

/** PSP-accepted refund: reverses the capture for the refunded amount. */
export function buildPspRefundLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    { accountCode: LEDGER_PSP_CUSTOMER_PREPAID_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: LEDGER_PSP_CLEARING_CODE, direction: 'CREDIT', amountVnd },
  ];
}

/** Online-paid job completed: the customer prepayment is now owed to the driver. */
export function buildPspPrepaidAppliedLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    { accountCode: LEDGER_PSP_CUSTOMER_PREPAID_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: LEDGER_PSP_PAYOUT_PAYABLE_CODE, direction: 'CREDIT', amountVnd },
  ];
}

/** Refund after settlement: DealGo expense against PSP clearing (driver payout unchanged). */
export function buildPspRefundAfterSettlementLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    { accountCode: LEDGER_PSP_REFUND_EXPENSE_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: LEDGER_PSP_CLEARING_CODE, direction: 'CREDIT', amountVnd },
  ];
}

/**
 * Verified driver prepayment: the money is an asset of DealGo but owed back to the driver
 * until it is used, so it credits a liability — never revenue at collection time.
 */
export function buildDriverCreditTopUpLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    { accountCode: LEDGER_PSP_CLEARING_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: LEDGER_DRIVER_CREDIT_LIABILITY_CODE, direction: 'CREDIT', amountVnd },
  ];
}

/** Prepaid credit pays accrued platform fees: the liability settles the receivable. */
export function buildDriverCreditAppliedLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    { accountCode: LEDGER_DRIVER_CREDIT_LIABILITY_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: LEDGER_FEE_DRIVER_RECEIVABLE_CODE, direction: 'CREDIT', amountVnd },
  ];
}

/** Ops refunds unused credit to the driver's verified bank account. */
export function buildDriverCreditRefundLines(amountVnd: number): CodJournalLine[] {
  if (!Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    throw new LedgerRuleError('LEDGER_AMOUNT_INVALID');
  }
  return [
    { accountCode: LEDGER_DRIVER_CREDIT_LIABILITY_CODE, direction: 'DEBIT', amountVnd },
    { accountCode: LEDGER_PSP_CLEARING_CODE, direction: 'CREDIT', amountVnd },
  ];
}

/** Ledger events that can be posted for a completed job, with their line builders. */
export type PostableLedgerEvent =
  | 'COD_OBLIGATION_POSTED'
  | 'PROMOTION_DISCOUNT_FUNDED'
  | 'DRIVER_PLATFORM_FEE_ACCRUED'
  | 'MERCHANT_COMMISSION_ACCRUED'
  | 'PSP_PAYMENT_CAPTURED'
  | 'PSP_REFUND_RECORDED'
  | 'PSP_PREPAID_APPLIED'
  | 'PSP_REFUND_AFTER_SETTLEMENT'
  | 'DRIVER_CREDIT_TOP_UP_CAPTURED'
  | 'DRIVER_CREDIT_APPLIED_TO_FEE'
  | 'DRIVER_CREDIT_REFUNDED';

export type LedgerLineBuilder = (
  amountVnd: number,
  entityType?: LedgerEntityTypeName,
) => CodJournalLine[];

export const LEDGER_LINE_BUILDERS: Readonly<Record<PostableLedgerEvent, LedgerLineBuilder>> = {
  COD_OBLIGATION_POSTED: buildCodObligationLines,
  PROMOTION_DISCOUNT_FUNDED: buildPromotionDiscountLines,
  DRIVER_PLATFORM_FEE_ACCRUED: buildDriverPlatformFeeLines,
  MERCHANT_COMMISSION_ACCRUED: buildMerchantCommissionLines,
  PSP_PAYMENT_CAPTURED: buildPspCaptureLines,
  PSP_REFUND_RECORDED: buildPspRefundLines,
  PSP_PREPAID_APPLIED: buildPspPrepaidAppliedLines,
  PSP_REFUND_AFTER_SETTLEMENT: buildPspRefundAfterSettlementLines,
  DRIVER_CREDIT_TOP_UP_CAPTURED: buildDriverCreditTopUpLines,
  DRIVER_CREDIT_APPLIED_TO_FEE: buildDriverCreditAppliedLines,
  DRIVER_CREDIT_REFUNDED: buildDriverCreditRefundLines,
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
