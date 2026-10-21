import { Module, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaModule } from '../database/prisma.module.js';
import { PrismaService } from '../database/prisma.service.js';
import { resolvePersistenceRepository } from '../database/resolve-persistence.js';
import type { AppEnv } from '../config/env.js';
import { IdentityModule } from '../../modules/identity/identity.module.js';
import { PLATFORM_SETTINGS_REPOSITORY } from './platform-settings.constants.js';
import {
  MemoryPlatformSettingsRepository,
  PrismaPlatformSettingsRepository,
  type PlatformSettingsRepository,
} from './platform-settings.repository.js';
import { PlatformSettingsService } from './platform-settings.service.js';
import { OpsPlatformSettingsController } from './platform-settings.controller.js';

@Module({
  imports: [PrismaModule, forwardRef(() => IdentityModule)],
  controllers: [OpsPlatformSettingsController],
  providers: [
    PlatformSettingsService,
    {
      provide: PLATFORM_SETTINGS_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): PlatformSettingsRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          PlatformSettingsRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryPlatformSettingsRepository(),
          createPrisma: (client) => new PrismaPlatformSettingsRepository(client),
        });
      },
    },
  ],
  exports: [PlatformSettingsService, PLATFORM_SETTINGS_REPOSITORY],
})
export class PlatformSettingsModule {}
