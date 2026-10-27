import { Module } from '@nestjs/common';
import { FoodModule } from '../food-order/food.module.js';
import { IdentityModule } from '../identity/index.js';
import { RideModule } from '../ride/ride.module.js';
import { CustomerActivityController } from './customer-activity.controller.js';
import { CustomerActivityService } from './customer-activity.service.js';

@Module({
  imports: [IdentityModule, RideModule, FoodModule],
  controllers: [CustomerActivityController],
  providers: [CustomerActivityService],
})
export class CustomerActivityModule {}
