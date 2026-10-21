import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';
import { PrismaModule, PrismaService, resolvePersistenceRepository } from '../../platform/database/index.js';
import { DriverCardModule } from '../driver-card/driver-card.module.js';
import { IdentityModule } from '../identity/index.js';
import { RideModule } from '../ride/ride.module.js';
import { PublicRideShareController, RideShareController } from './ride-share.controller.js';
import {
  MemoryRideShareRepository,
  PrismaRideShareRepository,
  RIDE_SHARE_REPOSITORY,
  type RideShareRepository,
} from './ride-share.repository.js';
import { RideShareService } from './ride-share.service.js';

@Module({
  imports: [PrismaModule, IdentityModule, RideModule, DriverCardModule],
  controllers: [RideShareController, PublicRideShareController],
  providers: [
    RideShareService,
    {
      provide: RIDE_SHARE_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): RideShareRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, RideShareRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryRideShareRepository(),
          createPrisma: (client) => new PrismaRideShareRepository(client),
        }),
    },
  ],
})
export class RideShareModule {}
