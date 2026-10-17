import { describe, expect, it } from 'vitest';
import {
  LEDGER_CASH_IN_TRANSIT_CODE,
  LEDGER_COD_OBLIGATION_CODE,
} from './ledger.constants.js';
import { assertBalancedLines, buildCodObligationLines } from './cod-journal.js';
import { LedgerRuleError } from './ledger.error.js';
import { MemoryLedgerRepository } from './ledger.repository.js';

describe('sandbox COD journal', () => {
  it('builds a balanced debit/credit pair for positive VND', () => {
    const lines = buildCodObligationLines(40_000);
    expect(lines).toEqual([
      {
        accountCode: LEDGER_CASH_IN_TRANSIT_CODE,
        direction: 'DEBIT',
        amountVnd: 40_000,
      },
      {
        accountCode: LEDGER_COD_OBLIGATION_CODE,
        direction: 'CREDIT',
        amountVnd: 40_000,
      },
    ]);
    expect(() => assertBalancedLines(lines)).not.toThrow();
  });

  it('rejects non-positive amounts', () => {
    expect(() => buildCodObligationLines(0)).toThrow(LedgerRuleError);
    expect(() => buildCodObligationLines(-1)).toThrow(LedgerRuleError);
  });

  it('posts idempotently per entity and event', async () => {
    const repo = new MemoryLedgerRepository();
    const first = await repo.postCodObligation({
      entityType: 'RIDE',
      entityId: '11111111-1111-1111-1111-111111111111',
      amountVnd: 40_000,
    });
    const second = await repo.postCodObligation({
      entityType: 'RIDE',
      entityId: '11111111-1111-1111-1111-111111111111',
      amountVnd: 40_000,
    });
    expect(second.id).toBe(first.id);
    expect(first.entries).toHaveLength(2);
    const debit = first.entries
      .filter((entry) => entry.direction === 'DEBIT')
      .reduce((sum, entry) => sum + entry.amountVnd, 0);
    const credit = first.entries
      .filter((entry) => entry.direction === 'CREDIT')
      .reduce((sum, entry) => sum + entry.amountVnd, 0);
    expect(debit).toBe(credit);
    expect(debit).toBe(40_000);
  });
});
