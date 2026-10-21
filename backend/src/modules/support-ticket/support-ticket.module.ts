import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';
import {
  PrismaModule,
  PrismaService,
  resolvePersistenceRepository,
} from '../../platform/database/index.js';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { StorageModule } from '../../platform/storage/storage.module.js';
import { InboxModule } from '../communication/inbox/inbox.module.js';
import { FoodModule } from '../food-order/food.module.js';
import { IdentityModule } from '../identity/index.js';
import { RideModule } from '../ride/ride.module.js';
import { SUPPORT_TICKET_REPOSITORY } from './support-ticket.constants.js';
import {
  OpsSupportTicketController,
  PublicSupportTicketController,
  SupportTicketController,
} from './support-ticket.controller.js';
import { PrismaSupportTicketRepository } from './support-ticket-prisma.repository.js';
import {
  MemorySupportTicketRepository,
  type SupportTicketRepository,
} from './support-ticket.repository.js';
import { SupportTicketService } from './support-ticket.service.js';

@Module({
  imports: [
    PrismaModule,
    IdentityModule,
    PlatformSettingsModule,
    StorageModule,
    InboxModule,
    RideModule,
    FoodModule,
  ],
  controllers: [SupportTicketController, PublicSupportTicketController, OpsSupportTicketController],
  providers: [
    SupportTicketService,
    {
      provide: SUPPORT_TICKET_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): SupportTicketRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, SupportTicketRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemorySupportTicketRepository(),
          createPrisma: (client) => new PrismaSupportTicketRepository(client),
        }),
    },
  ],
  exports: [SupportTicketService, SUPPORT_TICKET_REPOSITORY],
})
export class SupportTicketModule {}
