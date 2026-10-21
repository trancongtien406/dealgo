import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/index.js';
import { FoodModule } from '../food-order/index.js';
import { StorageModule } from '../../platform/storage/storage.module.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { CatalogService } from './catalog.service.js';
import { MerchantCatalogController } from './merchant-catalog.controller.js';
import { CatalogOpsController } from './catalog-ops.controller.js';
import { MenuItemImageService } from './menu-item-image.service.js';
import { PublicMenuItemImageController } from './menu-item-image.controller.js';
import { StoreLogoService } from './store-logo.service.js';
import { PublicStoreLogoController } from './store-logo.controller.js';

@Module({
  imports: [FoodModule, IdentityModule, StorageModule, PlatformSettingsModule],
  controllers: [
    MerchantCatalogController,
    CatalogOpsController,
    PublicMenuItemImageController,
    PublicStoreLogoController,
  ],
  providers: [CatalogService, MenuItemImageService, StoreLogoService],
  exports: [CatalogService, MenuItemImageService, StoreLogoService],
})
export class CatalogModule {}
