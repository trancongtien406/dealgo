import { Module } from '@nestjs/common';
import { EmailDeliveryModule } from '../../integrations/email/email-delivery.module.js';
import { IntegrationSettingsModule } from '../../platform/integration-settings/integration-settings.module.js';
import { IdentityModule } from '../identity/index.js';
import { OpsIntegrationsController, PublicClientConfigController } from './integrations-admin.controller.js';
import { INTEGRATIONS_FETCH, IntegrationsAdminService, type IntegrationsFetch } from './integrations-admin.service.js';

@Module({
  imports: [IdentityModule, EmailDeliveryModule, IntegrationSettingsModule],
  controllers: [OpsIntegrationsController, PublicClientConfigController],
  providers: [
    IntegrationsAdminService,
    { provide: INTEGRATIONS_FETCH, useValue: ((url, init) => fetch(url, init)) satisfies IntegrationsFetch },
  ],
})
export class IntegrationsAdminModule {}
