import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { AppCheckService } from './app-check.service.js';
import { AppCheckGuard } from './app-check.guard.js';

@Module({
  imports: [PlatformSettingsModule],
  providers: [
    AppCheckService,
    {
      provide: APP_GUARD,
      useClass: AppCheckGuard,
    },
  ],
  exports: [AppCheckService],
})
export class AppCheckModule {}

