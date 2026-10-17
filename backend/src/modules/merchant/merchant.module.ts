import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/index.js';
import { FoodModule } from '../food-order/index.js';
import { MerchantService } from './merchant.service.js';
import { MerchantOpsController } from './merchant-ops.controller.js';

@Module({
  imports: [FoodModule, IdentityModule],
  controllers: [MerchantOpsController],
  providers: [MerchantService],
  exports: [MerchantService],
})
export class MerchantModule {}
