import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MapsModule } from '../../integrations/maps/maps.module.js';
import type { AppEnv } from '../../platform/config/index.js';
import { PrismaModule, PrismaService, resolvePersistenceRepository } from '../../platform/database/index.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { IdentityModule } from '../identity/index.js';
import { PlaceHistoryController } from './place-history.controller.js';
import {
  MemoryPlaceHistoryRepository,
  PLACE_HISTORY_REPOSITORY,
  PrismaPlaceHistoryRepository,
  type PlaceHistoryRepository,
} from './place-history.repository.js';
import { PlaceHistoryService } from './place-history.service.js';
import { OpsMapsProvidersController } from './ops-maps-providers.controller.js';
import { OpsPlacesController } from './ops-places.controller.js';
import { PlacesController } from './places.controller.js';
import { PlacesService } from './places.service.js';

@Module({
  imports: [MapsModule, IdentityModule, PrismaModule, PlatformSettingsModule],
  controllers: [
    PlacesController,
    PlaceHistoryController,
    OpsMapsProvidersController,
    OpsPlacesController,
  ],
  providers: [
    PlacesService,
    PlaceHistoryService,
    {
      provide: PLACE_HISTORY_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): PlaceHistoryRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, PlaceHistoryRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryPlaceHistoryRepository(),
          createPrisma: (client) => new PrismaPlaceHistoryRepository(client),
        }),
    },
  ],
})
export class PlacesModule {}
