import { Module } from '@nestjs/common';
import { IntegrationSettingsModule } from '../../platform/integration-settings/integration-settings.module.js';
import { IdentityModule } from '../identity/index.js';
import {
  OpsSentrySettingsController,
  OpsSystemErrorsController,
} from './system-errors.controller.js';
import {
  SENTRY_FETCH,
  SystemErrorsService,
  type SentryFetch,
} from './system-errors.service.js';

@Module({
  imports: [IdentityModule, IntegrationSettingsModule],
  controllers: [OpsSentrySettingsController, OpsSystemErrorsController],
  providers: [
    SystemErrorsService,
    {
      provide: SENTRY_FETCH,
      useValue: ((url, init) => fetch(url, init)) satisfies SentryFetch,
    },
  ],
})
export class SystemErrorsModule {}
