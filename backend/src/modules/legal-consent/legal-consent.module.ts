import { Module } from '@nestjs/common';
import { EmailDeliveryModule } from '../../integrations/email/email-delivery.module.js';
import { PrismaModule } from '../../platform/database/index.js';
import { IdentityModule } from '../identity/index.js';
import { PublicPagesModule } from '../public-pages/public-pages.module.js';
import { LegalConsentController, OpsLegalVersionsController, PublicLegalDocumentsController } from './legal-consent.controller.js';
import { LegalConsentService } from './legal-consent.service.js';

@Module({
  imports: [PrismaModule, IdentityModule, PublicPagesModule, EmailDeliveryModule],
  controllers: [LegalConsentController, OpsLegalVersionsController, PublicLegalDocumentsController],
  providers: [LegalConsentService],
  exports: [LegalConsentService],
})
export class LegalConsentModule {}
