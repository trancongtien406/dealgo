import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  PrismaModule,
  PrismaService,
  resolvePersistenceRepository,
} from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { FoodModule } from '../food-order/food.module.js';
import { IdentityModule } from '../identity/index.js';
import { RideModule } from '../ride/ride.module.js';
import { RATING_REPOSITORY } from './rating.constants.js';
import { RatingController } from './rating.controller.js';
import { PrismaRatingRepository } from './rating-prisma.repository.js';
import { MemoryRatingRepository, type RatingRepository } from './rating.repository.js';
import { RatingService } from './rating.service.js';

@Module({
  imports: [PrismaModule, IdentityModule, RideModule, FoodModule, PlatformSettingsModule],
  controllers: [RatingController],
  providers: [
    RatingService,
    {
      provide: RATING_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): RatingRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, RatingRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryRatingRepository(),
          createPrisma: (client) => new PrismaRatingRepository(client),
        }),
    },
  ],
  exports: [RatingService, RATING_REPOSITORY],
})
export class RatingModule {}
