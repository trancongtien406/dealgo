import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { PrismaModule, PrismaService, resolvePersistenceRepository } from '../../platform/database/index.js';
import { StorageModule } from '../../platform/storage/storage.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import { FOOD_CATEGORY_REPOSITORY } from './food-category.constants.js';
import { FoodCategoryOpsController } from './food-category-ops.controller.js';
import { PublicFoodCategoryController } from './food-category-public.controller.js';
import {
  MemoryFoodCategoryRepository,
  PrismaFoodCategoryRepository,
  type FoodCategoryRepository,
} from './food-category.repository.js';
import { FoodCategoryService } from './food-category.service.js';

@Module({
  imports: [PrismaModule, IdentityModule, StorageModule],
  controllers: [FoodCategoryOpsController, PublicFoodCategoryController],
  providers: [
    FoodCategoryService,
    {
      provide: FOOD_CATEGORY_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): FoodCategoryRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, FoodCategoryRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryFoodCategoryRepository(),
          createPrisma: (client) => new PrismaFoodCategoryRepository(client),
        }),
    },
  ],
  exports: [FoodCategoryService],
})
export class FoodCategoryModule {}
