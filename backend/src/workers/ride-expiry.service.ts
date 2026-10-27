import { Injectable, Logger, Optional } from '@nestjs/common';
import { FoodService } from '../modules/food-order/food.service.js';
import { RideService } from '../modules/ride/index.js';

/**
 * Periodic lifecycle sweep (RIDE_EXPIRY_JOB interval):
 * - negotiating rides past their request window → EXPIRED;
 * - ASSIGNED/EN_ROUTE rides stuck past RIDE_ASSIGNED_START_TIMEOUT_MINUTES /
 *   RIDE_EN_ROUTE_TIMEOUT_MINUTES go back to negotiation (counted as driver cancellations);
 * - Food orders the merchant never accepted (FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES)
 *   or nobody claimed once READY (FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES) → CANCELLED by SYSTEM.
 * Returns the expired-ride count (kept for the existing heartbeat/log contract).
 */
@Injectable()
export class RideExpiryService {
  private readonly logger = new Logger(RideExpiryService.name);

  constructor(
    private readonly rides: RideService,
    @Optional() private readonly food?: FoodService,
  ) {}

  async runOnce(now?: Date): Promise<number> {
    const at = now ?? new Date();
    const { expiredIds } = await this.rides.expireDue(now);
    const returnedIds = (await this.rides.timeoutDue?.(now))?.returnedIds ?? [];
    const foodIds = this.food ? (await this.food.timeoutDue(at)).orderIds : [];
    if (expiredIds.length > 0 || returnedIds.length > 0 || foodIds.length > 0) {
      this.logger.log({
        msg: 'ride.expiry',
        expiredCount: expiredIds.length,
        rideTimeoutCount: returnedIds.length,
        foodTimeoutCount: foodIds.length,
        at: at.toISOString(),
      });
    }
    return expiredIds.length;
  }
}
