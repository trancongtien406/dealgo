import { Module } from '@nestjs/common';
import { EarningsModule } from '../earnings/earnings.module.js';
import { FoodModule } from '../food-order/food.module.js';
import { IdentityModule } from '../identity/index.js';
import { RatingModule } from '../rating/rating.module.js';
import { RideModule } from '../ride/ride.module.js';
import { DriverActiveJobController, DriverHistoryController } from './driver-history.controller.js';
import { DriverHistoryService } from './driver-history.service.js';

@Module({
  imports: [IdentityModule, RideModule, FoodModule, RatingModule, EarningsModule],
  controllers: [DriverHistoryController, DriverActiveJobController],
  providers: [DriverHistoryService],
  exports: [DriverHistoryService],
})
export class DriverHistoryModule {}
