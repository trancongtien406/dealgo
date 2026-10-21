import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';
import { PrismaModule, PrismaService, resolvePersistenceRepository } from '../../platform/database/index.js';
import { IdentityModule } from '../identity/index.js';
import { AuditModule } from '../../platform/audit/index.js';
import { OpsDisputesController } from './ops-disputes.controller.js';
import { OpsDisputesService } from './ops-disputes.service.js';
import {
  MemoryOpsFaqRepository,
  PrismaOpsFaqRepository,
  type OpsFaqRepository,
} from './ops-faq.repository.js';
import { OpsFaqService } from './ops-faq.service.js';
import { HelpFaqsController } from './help-faqs.controller.js';
import { OpsFaqsController } from './ops-faqs.controller.js';
import { OPS_FAQ_REPOSITORY } from './support.constants.js';

@Module({
  imports: [PrismaModule, IdentityModule, AuditModule],
  controllers: [OpsDisputesController, OpsFaqsController, HelpFaqsController],
  providers: [
    OpsDisputesService,
    OpsFaqService,
    {
      provide: OPS_FAQ_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): OpsFaqRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          OpsFaqRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryOpsFaqRepository(),
          createPrisma: (client) => new PrismaOpsFaqRepository(client),
        });
      },
    },
  ],
  exports: [OpsDisputesService, OpsFaqService, OPS_FAQ_REPOSITORY],
})
export class SupportModule {}
