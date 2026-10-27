import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { PrismaModule, PrismaService, resolvePersistenceRepository } from '../../platform/database/index.js';
import { StorageModule } from '../../platform/storage/storage.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import { HOME_BANNER_REPOSITORY } from './home-banner.constants.js';
import { HomeBannerOpsController } from './home-banner-ops.controller.js';
import { PublicHomeBannerController } from './home-banner-public.controller.js';
import {
  MemoryHomeBannerRepository,
  PrismaHomeBannerRepository,
  type HomeBannerRepository,
} from './home-banner.repository.js';
import { HomeBannerService } from './home-banner.service.js';

@Module({
  imports: [PrismaModule, IdentityModule, StorageModule],
  controllers: [HomeBannerOpsController, PublicHomeBannerController],
  providers: [
    HomeBannerService,
    {
      provide: HOME_BANNER_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): HomeBannerRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, HomeBannerRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryHomeBannerRepository(),
          createPrisma: (client) => new PrismaHomeBannerRepository(client),
        }),
    },
  ],
  exports: [HomeBannerService],
})
export class HomeBannerModule {}
