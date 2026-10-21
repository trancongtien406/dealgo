import { Inject, Injectable } from '@nestjs/common';
import type { TxHandle } from '../../shared/tx/completion-hook.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { EARNINGS_REPOSITORY, type EarningEntityType } from './earnings.constants.js';
import { percentToBps, splitFare } from './earnings.math.js';
import type { EarningsRepository, JobEarning } from './earnings.repository.js';

const FEE_SETTING = {
  RIDE: 'PLATFORM_FEE_RIDE_PERCENT',
  FOOD_ORDER: 'PLATFORM_FEE_FOOD_PERCENT',
} as const;

/**
 * Snapshots driver earnings when a job completes (confirmed DEC-PROD-014): the fee rate in force
 * at that moment is copied onto the job, so later setting changes never rewrite history.
 */
@Injectable()
export class EarningsService {
  constructor(
    @Inject(EARNINGS_REPOSITORY) private readonly earnings: EarningsRepository,
    private readonly settings: PlatformSettingsService,
    private readonly ledger: LedgerService,
  ) {}

  /** Fee rate in force now, in basis points (read before the completion transaction opens). */
  async currentFeeBps(entityType: EarningEntityType): Promise<number> {
    return percentToBps(await this.settings.getNumber(FEE_SETTING[entityType]));
  }

  /**
   * Writes the earnings snapshot and the platform-fee journal inside the completion transaction
   * (decision 2026-10-19, DEC-PROD-014): if either write fails, the completion rolls back instead
   * of silently recording a zero fee. Idempotent per job.
   */
  async recordWithin(
    tx: TxHandle,
    input: {
      entityType: EarningEntityType;
      entityId: string;
      driverId: string;
      fareVnd: number;
      completedAt: Date;
      feeBps: number;
    },
  ): Promise<JobEarning> {
    const { feeVnd, netVnd } = splitFare(input.fareVnd, input.feeBps);
    const earning = await this.earnings.recordWithin(tx, { ...input, feeVnd, netVnd });
    if (earning.feeVnd > 0) {
      await this.ledger.postWithin(tx, 'DRIVER_PLATFORM_FEE_ACCRUED', {
        entityType: earning.entityType,
        entityId: earning.entityId,
        amountVnd: earning.feeVnd,
      });
    }
    return earning;
  }

  findMany(subjects: { entityType: EarningEntityType; entityId: string }[]) {
    return this.earnings.findMany(subjects);
  }
}
