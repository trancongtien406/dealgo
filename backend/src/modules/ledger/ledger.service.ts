import { Inject, Injectable } from '@nestjs/common';
import type { RequestActor } from '../identity/access-auth.guard.js';
import { LEDGER_REPOSITORY, type LedgerEntityTypeName } from './ledger.constants.js';
import { LedgerRuleError, ledgerError } from './ledger.error.js';
import type { LedgerJournalView, LedgerRepository } from './ledger.repository.js';
import type { PostableLedgerEvent } from './cod-journal.js';
import type { TxHandle } from '../../shared/tx/completion-hook.js';

@Injectable()
export class LedgerService {
  constructor(@Inject(LEDGER_REPOSITORY) private readonly ledger: LedgerRepository) {}

  async postCodObligation(input: {
    entityType: LedgerEntityTypeName;
    entityId: string;
    amountVnd: number;
  }): Promise<LedgerJournalView> {
    try {
      return await this.ledger.postCodObligation(input);
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  async postPromotionDiscount(input: {
    entityType: LedgerEntityTypeName;
    entityId: string;
    amountVnd: number;
  }): Promise<LedgerJournalView> {
    try {
      return await this.ledger.postPromotionDiscount(input);
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  async postDriverPlatformFee(input: {
    entityType: LedgerEntityTypeName;
    entityId: string;
    amountVnd: number;
  }): Promise<LedgerJournalView> {
    try {
      return await this.ledger.postDriverPlatformFee(input);
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  /** Posts inside the job's completion transaction; a failure rolls the completion back. */
  async postWithin(
    tx: TxHandle,
    event: PostableLedgerEvent,
    input: { entityType: LedgerEntityTypeName; entityId: string; amountVnd: number },
  ): Promise<LedgerJournalView> {
    try {
      return await this.ledger.postWithin(tx, event, input);
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  async getJournal(
    entityType: LedgerEntityTypeName,
    entityId: string,
  ): Promise<LedgerJournalView> {
    const journal = await this.ledger.findByEntity(entityType, entityId);
    if (!journal) {
      throw ledgerError(404, 'LEDGER_JOURNAL_NOT_FOUND', 'Ledger journal not found');
    }
    return journal;
  }

  async getJournalForOps(
    _actor: RequestActor,
    entityType: LedgerEntityTypeName,
    entityId: string,
  ): Promise<LedgerJournalView> {
    return this.getJournal(entityType, entityId);
  }

  private asHttp(error: unknown): unknown {
    if (error instanceof LedgerRuleError) {
      return ledgerError(error.status, error.code, error.message);
    }
    return error;
  }
}
