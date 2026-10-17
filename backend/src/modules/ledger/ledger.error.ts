import { HttpException } from '@nestjs/common';

export function ledgerError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ message, errorCode }, status);
}

export const LEDGER_RULES = {
  LEDGER_AMOUNT_INVALID: { status: 400, message: 'Ledger amount must be a positive integer VND' },
  LEDGER_UNBALANCED: { status: 500, message: 'Ledger journal is unbalanced' },
  LEDGER_JOURNAL_NOT_FOUND: { status: 404, message: 'Ledger journal not found' },
  LEDGER_ACCOUNT_MISSING: { status: 500, message: 'Sandbox ledger accounts are not seeded' },
} as const;

export type LedgerRuleCode = keyof typeof LEDGER_RULES;

export class LedgerRuleError extends Error {
  readonly status: number;
  readonly code: LedgerRuleCode;

  constructor(code: LedgerRuleCode) {
    const rule = LEDGER_RULES[code];
    super(rule.message);
    this.name = 'LedgerRuleError';
    this.code = code;
    this.status = rule.status;
  }
}
