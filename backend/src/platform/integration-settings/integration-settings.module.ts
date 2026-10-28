import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import { PrismaModule } from '../database/prisma.module.js';
import { PrismaService } from '../database/prisma.service.js';
import { resolvePersistenceRepository } from '../database/resolve-persistence.js';
import { INTEGRATION_SETTINGS_REPOSITORY } from './integration-settings.constants.js';
import {
  MemoryIntegrationSettingsRepository,
  PrismaIntegrationSettingsRepository,
  type IntegrationSettingsRepository,
} from './integration-settings.repository.js';
import { IntegrationSettingsService } from './integration-settings.service.js';
import { MapKeysService } from './map-keys.service.js';

/** Encrypted Admin overrides for integration credentials; no controllers (see IntegrationSettingsOpsModule). */
@Module({
  imports: [PrismaModule],
  providers: [
    IntegrationSettingsService,
    MapKeysService,
    {
      provide: INTEGRATION_SETTINGS_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): IntegrationSettingsRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, IntegrationSettingsRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryIntegrationSettingsRepository(),
          createPrisma: (client) => new PrismaIntegrationSettingsRepository(client),
        }),
    },
  ],
  exports: [IntegrationSettingsService, MapKeysService],
})
export class IntegrationSettingsModule {}
