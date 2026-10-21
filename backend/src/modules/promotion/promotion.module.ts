import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';
import {
  PrismaModule,
  PrismaService,
  resolvePersistenceRepository,
} from '../../platform/database/index.js';
import { IdentityModule } from '../identity/index.js';
import { PROMOTION_REPOSITORY } from './promotion.constants.js';
import { PromotionClientController } from './promotion-client.controller.js';
import { PromotionOpsController } from './promotion-ops.controller.js';
import { PrismaPromotionRepository } from './promotion-prisma.repository.js';
import {
  MemoryPromotionRepository,
  type PromotionRepository,
} from './promotion.repository.js';
import { PromotionService } from './promotion.service.js';

@Module({
  imports: [PrismaModule, IdentityModule],
  controllers: [PromotionOpsController, PromotionClientController],
  providers: [
    PromotionService,
    {
      provide: PROMOTION_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): PromotionRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          PromotionRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryPromotionRepository(),
          createPrisma: (client) => new PrismaPromotionRepository(client),
        });
      },
    },
  ],
  exports: [PromotionService, PROMOTION_REPOSITORY],
})
export class PromotionModule {}
