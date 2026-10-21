import { Module } from '@nestjs/common';
import { FoodModule } from '../food-order/food.module.js';
import { IdentityModule } from '../identity/index.js';
import { PartnerModule } from '../partner/index.js';
import { RatingModule } from '../rating/rating.module.js';
import { RideModule } from '../ride/ride.module.js';
import { DriverCardController } from './driver-card.controller.js';
import { DriverCardService } from './driver-card.service.js';
import { OpsPeopleController } from './ops-people.controller.js';

@Module({
  imports: [IdentityModule, PartnerModule, RatingModule, RideModule, FoodModule],
  controllers: [DriverCardController, OpsPeopleController],
  providers: [DriverCardService],
  exports: [DriverCardService],
})
export class DriverCardModule {}
