export const LEDGER_REPOSITORY = Symbol('LEDGER_REPOSITORY');

export const LEDGER_CASH_IN_TRANSIT_CODE = 'sandbox.cod.cash_in_transit';
export const LEDGER_COD_OBLIGATION_CODE = 'sandbox.cod.obligation';

export type LedgerEntityTypeName = 'RIDE' | 'FOOD_ORDER' | 'DISPUTE';
export type LedgerJournalEventName = 'COD_OBLIGATION_POSTED' | 'SANDBOX_REFUND_RECORDED';

export const LEDGER_REFUND_PAYABLE_CODE = 'sandbox.refund.payable';
export const LEDGER_REFUND_CLEARING_CODE = 'sandbox.refund.clearing';
export type LedgerJournalStatusName = 'POSTED';
export type LedgerEntryDirectionName = 'DEBIT' | 'CREDIT';
