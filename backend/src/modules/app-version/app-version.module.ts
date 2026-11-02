import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { IdentityModule } from '../identity/index.js';
import { AppVersionController, OpsAppVersionController } from './app-version.controller.js';
import { AppVersionGuard } from './app-version.guard.js';
import { AppVersionService } from './app-version.service.js';

@Module({
  imports: [PlatformSettingsModule, IdentityModule],
  controllers: [AppVersionController, OpsAppVersionController],
  providers: [AppVersionService, { provide: APP_GUARD, useClass: AppVersionGuard }],
  exports: [AppVersionService],
})
export class AppVersionModule {}
