import { HttpException, Inject, Injectable } from '@nestjs/common';
import type { BalanceAdjustment, BalanceAdjustmentInput, DriverBalance } from './driver-balance.js';
import type { TxHandle } from '../../shared/tx/completion-hook.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { isBikeClass } from '../ride-vehicle/ride-vehicle-class.js';
import { EARNINGS_REPOSITORY, type EarningEntityType } from './earnings.constants.js';
import { percentToBps, splitFare } from './earnings.math.js';
import type { EarningsRepository, JobEarning } from './earnings.repository.js';

export type DriverCancelRate = {
  windowDays: number;
  cancelled: number;
  completed: number;
  percent: number;
  warnPercent: number;
  warn: boolean;
};

/**
 * (DEC-PROD-062) The driver commission depends on the service — motorbike ride, car ride, or food
 * delivery (on the delivery fee only; the merchant commission is separate, see FoodService).
 */
export function driverCommissionSettingKey(
  entityType: EarningEntityType,
  vehicleClassCode?: string | null,
): 'RIDE_COMMISSION_BIKE_PERCENT' | 'RIDE_COMMISSION_CAR_PERCENT' | 'FOOD_DRIVER_COMMISSION_PERCENT' {
  if (entityType === 'FOOD_ORDER') {
    return 'FOOD_DRIVER_COMMISSION_PERCENT';
  }
  return isBikeClass(vehicleClassCode) ? 'RIDE_COMMISSION_BIKE_PERCENT' : 'RIDE_COMMISSION_CAR_PERCENT';
}

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

  /**
   * Driver commission in force now, in basis points (read before the completion transaction
   * opens). Rides pick the motorbike or car rate from the ride's vehicle class.
   */
  async currentFeeBps(entityType: EarningEntityType, vehicleClassCode?: string | null): Promise<number> {
    return percentToBps(
      await this.settings.getNumber(driverCommissionSettingKey(entityType, vehicleClassCode)),
    );
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

  /** Signed driver balance movement, idempotent per ref (inside the job tx). */
  adjustWithin(tx: TxHandle, input: BalanceAdjustmentInput): Promise<void> {
    if (!Number.isSafeInteger(input.amountVnd) || input.amountVnd === 0) {
      return Promise.resolve();
    }
    return this.earnings.adjustWithin(tx, input);
  }

  balanceOf(driverId: string): Promise<DriverBalance> {
    return this.earnings.balanceOf(driverId);
  }

  listAdjustments(driverId: string, limit = 50): Promise<BalanceAdjustment[]> {
    return this.earnings.listAdjustments(driverId, Math.min(Math.max(limit, 1), 200));
  }

  /**
   * Driver cancellation rate over DRIVER_CANCEL_RATE_WINDOW_DAYS =
   * dropped jobs / (dropped + completed), as Grab/Be show drivers an acceptance/cancel rate.
   * Ops sees `warn` above DRIVER_CANCEL_RATE_WARN_PERCENT; it is not an automatic block.
   */
  async cancelRate(driverId: string, now = new Date()): Promise<DriverCancelRate> {
    const windowDays = await this.settings.getNumber('DRIVER_CANCEL_RATE_WINDOW_DAYS');
    const warnPercent = await this.settings.getNumber('DRIVER_CANCEL_RATE_WARN_PERCENT');
    const since = new Date(now.getTime() - windowDays * 86_400_000);
    const { cancelled, completed } = await this.earnings.jobOutcomesSince(driverId, since);
    const total = cancelled + completed;
    const percent = total === 0 ? 0 : Math.round((cancelled / total) * 1000) / 10;
    return {
      windowDays,
      cancelled,
      completed,
      percent,
      warnPercent,
      warn: warnPercent > 0 && total > 0 && percent > warnPercent,
    };
  }

  /**
   * (DRIVER_DEBT_LIMIT_VND, DRAFT 200,000 VND): a driver whose unpaid cash balance
   * (platform fees + adjustments since the last settlement) exceeds the limit cannot browse
   * or take new jobs until Ops records a settlement. 0 disables the check.
   */
  async assertUnderDebtLimit(driverId: string): Promise<void> {
    const limit = await this.settings.getNumber('DRIVER_DEBT_LIMIT_VND');
    if (!(limit > 0)) {
      return;
    }
    const balance = await this.earnings.balanceOf(driverId);
    if (balance.amountVnd > limit) {
      throw new HttpException(
        {
          message: 'Unpaid platform balance is over the limit; settle it with DealGo to take new jobs',
          errorCode: 'DRIVER_DEBT_LIMIT_REACHED',
          balanceVnd: balance.amountVnd,
          limitVnd: limit,
        },
        403,
      );
    }
  }
}
