import { Injectable, Logger } from '@nestjs/common';
import { RideService } from '../modules/ride/index.js';

@Injectable()
export class RideExpiryService {
  private readonly logger = new Logger(RideExpiryService.name);

  constructor(private readonly rides: RideService) {}

  async runOnce(now?: Date): Promise<number> {
    const { expiredIds } = await this.rides.expireDue(now);
    if (expiredIds.length > 0) {
      this.logger.log({
        msg: 'ride.expiry',
        expiredCount: expiredIds.length,
        at: (now ?? new Date()).toISOString(),
      });
    }
    return expiredIds.length;
  }
}
