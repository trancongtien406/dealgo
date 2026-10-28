import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/index.js';
import { FoodModule } from '../food-order/index.js';
import { FoodCategoryModule } from '../food-category/index.js';
import { StorageModule } from '../../platform/storage/storage.module.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { CatalogService } from './catalog.service.js';
import { MerchantCatalogController } from './merchant-catalog.controller.js';
import { MerchantPromotionController } from './merchant-promotion.controller.js';
import { PromotionModule } from '../promotion/index.js';
import { CatalogOpsController } from './catalog-ops.controller.js';
import { MenuItemImageService } from './menu-item-image.service.js';
import { PublicMenuItemImageController } from './menu-item-image.controller.js';
import { StoreLogoService } from './store-logo.service.js';
import {
  PublicStoreCoverController,
  PublicStoreLogoController,
} from './store-logo.controller.js';

@Module({
  imports: [
    FoodModule,
    PromotionModule,
    FoodCategoryModule,
    IdentityModule,
    StorageModule,
    PlatformSettingsModule,
  ],
  controllers: [
    MerchantCatalogController,
    MerchantPromotionController,
    CatalogOpsController,
    PublicMenuItemImageController,
    PublicStoreLogoController,
    PublicStoreCoverController,
  ],
  providers: [CatalogService, MenuItemImageService, StoreLogoService],
  exports: [CatalogService, MenuItemImageService, StoreLogoService],
})
export class CatalogModule {}
