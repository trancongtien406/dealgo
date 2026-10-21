import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { IdentityModule } from '../identity/index.js';
import { EarningsModule } from '../earnings/earnings.module.js';
import { LedgerModule } from '../ledger/index.js';
import { MapsModule } from '../../integrations/maps/index.js';
import { PartnerModule } from '../partner/index.js';
import { PaymentModule } from '../payment/index.js';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { PROMOTION_REPOSITORY, PromotionModule, type PromotionRepository } from '../promotion/index.js';
import { FOOD_REPOSITORY } from './food.constants.js';
import { FoodController } from './food.controller.js';
import { MemoryFoodRepository, type FoodRepository } from './food.repository.js';
import { FoodService } from './food.service.js';
import { FoodOrderOpsController } from './food-order-ops.controller.js';
import { PrismaFoodRepository } from './food-prisma.repository.js';
import {
  FOOD_ORDER_CODE_STORE,
  MemoryFoodOrderCodeStore,
  PrismaFoodOrderCodeStore,
  type FoodOrderCodeStore,
} from './food-order-code.js';

@Module({
  imports: [
    IdentityModule,
    PrismaModule,
    LedgerModule,
    PartnerModule,
    MapsModule,
    PaymentModule,
    PlatformSettingsModule,
    PromotionModule,
    EarningsModule,
  ],
  controllers: [
    FoodController,
    FoodOrderOpsController,
  ],
  providers: [
    FoodService,
    {
      provide: FOOD_REPOSITORY,
      inject: [PrismaService, ConfigService, PROMOTION_REPOSITORY],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
        promotions: PromotionRepository,
      ): FoodRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          FoodRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryFoodRepository(promotions),
          createPrisma: (client) => new PrismaFoodRepository(client),
        });
      },
    },
    {
      provide: FOOD_ORDER_CODE_STORE,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): FoodOrderCodeStore =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, FoodOrderCodeStore>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryFoodOrderCodeStore(),
          createPrisma: (client) => new PrismaFoodOrderCodeStore(client),
        }),
    },
  ],
  exports: [FoodService],
})
export class FoodModule {}
export { FoodModule as FoodOrderModule };

