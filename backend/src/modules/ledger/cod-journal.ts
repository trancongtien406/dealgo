import {
  LEDGER_CASH_IN_TRANSIT_CODE,
  LEDGER_COD_OBLIGATION_CODE,
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
