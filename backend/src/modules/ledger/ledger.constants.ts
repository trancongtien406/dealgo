export const LEDGER_REPOSITORY = Symbol('LEDGER_REPOSITORY');

export const LEDGER_CASH_IN_TRANSIT_CODE = 'sandbox.cod.cash_in_transit';
export const LEDGER_COD_OBLIGATION_CODE = 'sandbox.cod.obligation';

export type LedgerEntityTypeName = 'RIDE' | 'FOOD_ORDER' | 'DISPUTE';
export type LedgerJournalEventName =
  | 'COD_OBLIGATION_POSTED'
  | 'SANDBOX_REFUND_RECORDED'
  | 'PROMOTION_DISCOUNT_FUNDED'
  | 'DRIVER_PLATFORM_FEE_ACCRUED'
  | 'MERCHANT_COMMISSION_ACCRUED'
  | 'PSP_PAYMENT_CAPTURED'
  | 'PSP_REFUND_RECORDED';

/** DealGo-funded voucher discounts (proposed decision, see decisions-and-assumptions). */
export const LEDGER_PROMO_EXPENSE_CODE = 'sandbox.promo.discount_expense';
export const LEDGER_PROMO_MERCHANT_PAYABLE_CODE = 'sandbox.promo.merchant_payable';
/** DEC-PROD-024: DealGo-funded ride voucher discounts are owed to the driver. */
export const LEDGER_PROMO_DRIVER_PAYABLE_CODE = 'sandbox.promo.driver_payable';

/** Platform fee withheld from the driver's fare (rate snapshotted at completion). */
export const LEDGER_FEE_DRIVER_RECEIVABLE_CODE = 'sandbox.fee.driver_receivable';
export const LEDGER_FEE_REVENUE_CODE = 'sandbox.fee.platform_revenue';

/** Commission a merchant owes DealGo on delivered food orders. */
export const LEDGER_COMMISSION_MERCHANT_RECEIVABLE_CODE = 'sandbox.commission.merchant_receivable';
export const LEDGER_COMMISSION_REVENUE_CODE = 'sandbox.commission.revenue';

/** Online payments: money held by the PSP for DealGo vs prepaid by the customer. */
export const LEDGER_PSP_CLEARING_CODE = 'psp.clearing_receivable';
export const LEDGER_PSP_CUSTOMER_PREPAID_CODE = 'psp.customer_prepaid';

export const LEDGER_REFUND_PAYABLE_CODE = 'sandbox.refund.payable';
export const LEDGER_REFUND_CLEARING_CODE = 'sandbox.refund.clearing';
export type LedgerJournalStatusName = 'POSTED';
export type LedgerEntryDirectionName = 'DEBIT' | 'CREDIT';
