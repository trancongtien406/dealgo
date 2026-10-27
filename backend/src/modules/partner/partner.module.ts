import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { IdentityModule } from '../identity/index.js';
import { PARTNER_REPOSITORY } from './partner.constants.js';
import { MePartnerApplicationsController } from './me-partner-applications.controller.js';
import { OpsPartnerApplicationsController } from './ops-partner-applications.controller.js';
import { PartnerEligibilityService } from './partner-eligibility.service.js';
import { MemoryPartnerRepository, type PartnerRepository } from './partner.repository.js';
import { PartnerService } from './partner.service.js';
import { PrismaPartnerRepository } from './partner-prisma.repository.js';
import { RideVehicleClassModule } from '../ride-vehicle/ride-vehicle-class.module.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { StorageModule } from '../../platform/storage/storage.module.js';

@Module({
  imports: [
    PrismaModule,
    IdentityModule,
    StorageModule,
    RideVehicleClassModule,
    PlatformSettingsModule,
  ],
  controllers: [MePartnerApplicationsController, OpsPartnerApplicationsController],
  providers: [
    {
      provide: PARTNER_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): PartnerRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          PartnerRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryPartnerRepository(),
          createPrisma: (client) => new PrismaPartnerRepository(client),
        });
      },
    },
    PartnerService,
    PartnerEligibilityService,
  ],
  exports: [PartnerEligibilityService, PARTNER_REPOSITORY, PartnerService],
})
export class PartnerModule {}
