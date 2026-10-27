import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { IdentityModule } from '../identity/index.js';
import { EarningsModule } from '../earnings/earnings.module.js';
import { LedgerModule } from '../ledger/index.js';
import { MapsModule } from '../../integrations/maps/index.js';
import { PartnerModule } from '../partner/index.js';
import { PaymentModule } from '../payment/index.js';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { PROMOTION_REPOSITORY, PromotionModule, type PromotionRepository } from '../promotion/index.js';
import { RideOpsController } from './ride-ops.controller.js';
import {
  MemoryRidePickupCodeStore,
  PrismaRidePickupCodeStore,
  RIDE_PICKUP_CODE_STORE,
  type RidePickupCodeStore,
} from './ride-pickup-code.js';
import { PrismaRideRepository } from './ride-prisma.repository.js';
import {
  MemoryRideCustomerRatingStore,
  PrismaRideCustomerRatingStore,
  RIDE_CUSTOMER_RATING_STORE,
  type RideCustomerRatingStore,
} from './ride-customer-rating.js';
import { RIDE_CLOCK, RIDE_REPOSITORY, SystemRideClock } from './ride.constants.js';
import { RideController } from './ride.controller.js';
import { MemoryRideRepository, type RideRepository } from './ride.repository.js';
import { RideVehicleClassModule } from '../ride-vehicle/ride-vehicle-class.module.js';
import { RoutingModule } from '../routing/index.js';
import { RideService } from './ride.service.js';
import { RideOfferEvents } from './ride-offer-events.js';

@Module({
  imports: [
    IdentityModule,
    PrismaModule,
    LedgerModule,
    PartnerModule,
    MapsModule,
    PaymentModule,
    PlatformSettingsModule,
    EarningsModule,
    PromotionModule,
    RideVehicleClassModule,
    RoutingModule,
  ],
  controllers: [RideController, RideOpsController],
  providers: [
    RideService,
    RideOfferEvents,
    SystemRideClock,
    { provide: RIDE_CLOCK, useExisting: SystemRideClock },
    {
      provide: RIDE_REPOSITORY,
      inject: [PrismaService, ConfigService, PROMOTION_REPOSITORY],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
        promotions: PromotionRepository,
      ): RideRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          RideRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryRideRepository(promotions),
          createPrisma: (client) => new PrismaRideRepository(client),
        });
      },
    },
    {
      provide: RIDE_CUSTOMER_RATING_STORE,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): RideCustomerRatingStore =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, RideCustomerRatingStore>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryRideCustomerRatingStore(),
          createPrisma: (client) => new PrismaRideCustomerRatingStore(client),
        }),
    },
    {
      provide: RIDE_PICKUP_CODE_STORE,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): RidePickupCodeStore =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, RidePickupCodeStore>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryRidePickupCodeStore(),
          createPrisma: (client) => new PrismaRidePickupCodeStore(client),
        }),
    },
  ],
  exports: [RideService, RIDE_CLOCK, RideOfferEvents],
})
export class RideModule {}
