import { Module } from '@nestjs/common';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { IdentityModule } from '../identity/index.js';
import {
  OpsSiteConfigController,
  PublicSiteConfigController,
} from './site-config.controller.js';
import { SiteConfigService } from './site-config.service.js';

@Module({
  imports: [PlatformSettingsModule, IdentityModule],
  controllers: [PublicSiteConfigController, OpsSiteConfigController],
  providers: [SiteConfigService],
})
export class SiteConfigModule {}
