import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/index.js';
import { FoodModule } from '../food-order/index.js';
import { CatalogService } from './catalog.service.js';
import { MerchantCatalogController } from './merchant-catalog.controller.js';
import { CatalogOpsController } from './catalog-ops.controller.js';

@Module({
  imports: [FoodModule, IdentityModule],
  controllers: [MerchantCatalogController, CatalogOpsController],
  providers: [CatalogService],
  exports: [CatalogService],
})
export class CatalogModule {}
