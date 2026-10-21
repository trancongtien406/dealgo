import { Module } from '@nestjs/common';
import { PrismaModule } from '../../platform/database/index.js';
import { IdentityModule } from '../identity/identity.module.js';
import { AccountSettingsController } from './account-settings.controller.js';
import { AccountSettingsService } from './account-settings.service.js';

@Module({
  imports: [PrismaModule, IdentityModule],
  controllers: [AccountSettingsController],
  providers: [AccountSettingsService],
  exports: [AccountSettingsService],
})
export class AccountSettingsModule {}
