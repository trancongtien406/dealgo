import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { PrismaModule, PrismaService, resolvePersistenceRepository } from '../../platform/database/index.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { StorageModule } from '../../platform/storage/storage.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import { RIDE_VEHICLE_CLASS_REPOSITORY, RIDE_ZONE_TARIFF_REPOSITORY } from './ride-vehicle-class.constants.js';
import { PublicRideVehicleClassImageController } from './ride-vehicle-class-image.controller.js';
import { RideVehicleClassOpsController } from './ride-vehicle-class-ops.controller.js';
import {
  MemoryRideVehicleClassRepository,
  PrismaRideVehicleClassRepository,
  type RideVehicleClassRepository,
} from './ride-vehicle-class.repository.js';
import { RideVehicleClassService } from './ride-vehicle-class.service.js';
import { RideZoneTariffOpsController } from './ride-zone-tariff-ops.controller.js';
import {
  MemoryRideZoneTariffRepository,
  PrismaRideZoneTariffRepository,
  type RideZoneTariffRepository,
} from './ride-zone-tariff.repository.js';
import { RideZoneTariffService } from './ride-zone-tariff.service.js';

@Module({
  imports: [PrismaModule, PlatformSettingsModule, IdentityModule, StorageModule],
  controllers: [RideVehicleClassOpsController, RideZoneTariffOpsController, PublicRideVehicleClassImageController],
  providers: [
    RideVehicleClassService,
    RideZoneTariffService,
    {
      provide: RIDE_ZONE_TARIFF_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): RideZoneTariffRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, RideZoneTariffRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryRideZoneTariffRepository(),
          createPrisma: (client) => new PrismaRideZoneTariffRepository(client),
        }),
    },
    {
      provide: RIDE_VEHICLE_CLASS_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): RideVehicleClassRepository =>
        resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          RideVehicleClassRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryRideVehicleClassRepository(),
          createPrisma: (client) => new PrismaRideVehicleClassRepository(client),
        }),
    },
  ],
  exports: [RideVehicleClassService, RideZoneTariffService],
})
export class RideVehicleClassModule {}
