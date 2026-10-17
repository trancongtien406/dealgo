import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../../platform/database/index.js';
import type { AppEnv } from '../../../platform/config/index.js';
import { PushModule } from '../../../integrations/push/index.js';
import { RealtimeModule } from '../realtime/index.js';
import { RideModule } from '../../ride/index.js';
import { FoodModule } from '../../food-order/index.js';
import { OutboxRelayService } from './outbox-relay.service.js';
import { OUTBOX_REPOSITORY } from './outbox.constants.js';
import { MemoryOutboxRepository, type OutboxRepository } from './outbox.repository.js';
import { PrismaOutboxRepository } from './outbox-prisma.repository.js';

@Module({
  imports: [
    PrismaModule,
    PushModule,
    RealtimeModule,
    RideModule,
    FoodModule,
  ],
  providers: [
    OutboxRelayService,
    {
      provide: OUTBOX_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): OutboxRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          OutboxRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryOutboxRepository(),
          createPrisma: (client) => new PrismaOutboxRepository(client),
        });
      },
    },
  ],
  exports: [OutboxRelayService, OUTBOX_REPOSITORY],
})
export class OutboxModule {}
