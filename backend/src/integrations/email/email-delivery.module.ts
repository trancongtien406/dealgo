import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { PrismaModule } from '../../platform/database/prisma.module.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { resolvePersistenceRepository } from '../../platform/database/resolve-persistence.js';
import { IntegrationSettingsModule } from '../../platform/integration-settings/integration-settings.module.js';
import { IntegrationSettingsService } from '../../platform/integration-settings/integration-settings.service.js';
import { DynamicMailSender } from './dynamic-mail-sender.js';
import {
  EMAIL_SUPPRESSION_REPOSITORY,
  MemoryEmailSuppressionRepository,
  PrismaEmailSuppressionRepository,
  type EmailSuppressionRepository,
} from './email-suppression.repository.js';
import { SesWebhookController } from './ses-webhook.controller.js';
import { SnsSignatureVerifier } from './sns-message.js';

/** Email transport chosen in Admin (DB) over env, plus SES bounce/complaint suppression. */
@Module({
  imports: [PrismaModule, IntegrationSettingsModule],
  controllers: [SesWebhookController],
  providers: [
    { provide: SnsSignatureVerifier, useFactory: () => new SnsSignatureVerifier() },
    {
      provide: EMAIL_SUPPRESSION_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): EmailSuppressionRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, EmailSuppressionRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryEmailSuppressionRepository(),
          createPrisma: (client) => new PrismaEmailSuppressionRepository(client),
        }),
    },
    {
      provide: DynamicMailSender,
      inject: [ConfigService, IntegrationSettingsService, EMAIL_SUPPRESSION_REPOSITORY],
      useFactory: (
        config: ConfigService<AppEnv, true>,
        settings: IntegrationSettingsService,
        suppressions: EmailSuppressionRepository,
      ) =>
        new DynamicMailSender(
          {
            NODE_ENV: config.get('NODE_ENV', { infer: true }),
            EMAIL_PROVIDER: config.get('EMAIL_PROVIDER', { infer: true }),
            EMAIL_FROM: config.get('EMAIL_FROM', { infer: true }),
            SMTP_URL: config.get('SMTP_URL', { infer: true }),
            SMTP_FROM: config.get('SMTP_FROM', { infer: true }),
            SES_REGION: config.get('SES_REGION', { infer: true }),
            SES_ACCESS_KEY_ID: config.get('SES_ACCESS_KEY_ID', { infer: true }),
            SES_SECRET_ACCESS_KEY: config.get('SES_SECRET_ACCESS_KEY', { infer: true }),
            SES_CONFIGURATION_SET: config.get('SES_CONFIGURATION_SET', { infer: true }),
            EMAIL_HTTP_TIMEOUT_MS: config.get('EMAIL_HTTP_TIMEOUT_MS', { infer: true }),
          },
          settings,
          suppressions,
        ),
    },
  ],
  exports: [DynamicMailSender, EMAIL_SUPPRESSION_REPOSITORY],
})
export class EmailDeliveryModule {}
