import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { IdentityModule } from '../identity/index.js';
import { LedgerModule } from '../ledger/index.js';
import { MapsModule } from '../../integrations/maps/index.js';
import { PartnerModule } from '../partner/index.js';
import { PaymentModule } from '../payment/index.js';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { RideOpsController } from './ride-ops.controller.js';
import { PrismaRideRepository } from './ride-prisma.repository.js';
import { RIDE_CLOCK, RIDE_REPOSITORY, SystemRideClock } from './ride.constants.js';
import { RideController } from './ride.controller.js';
import { MemoryRideRepository, type RideRepository } from './ride.repository.js';
import { RideService } from './ride.service.js';

@Module({
  imports: [
    IdentityModule,
    PrismaModule,
    LedgerModule,
    PartnerModule,
    MapsModule,
    PaymentModule,
    PlatformSettingsModule,
  ],
  controllers: [RideController, RideOpsController],
  providers: [
    RideService,
    SystemRideClock,
    { provide: RIDE_CLOCK, useExisting: SystemRideClock },
    {
      provide: RIDE_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): RideRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          RideRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryRideRepository(),
          createPrisma: (client) => new PrismaRideRepository(client),
        });
      },
    },
  ],
  exports: [RideService, RIDE_CLOCK],
})
export class RideModule {}
