import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  PrismaModule,
  PrismaService,
  resolvePersistenceRepository,
} from '../../../platform/database/index.js';
import type { AppEnv } from '../../../platform/config/index.js';
import { IdentityModule } from '../../identity/index.js';
import { INBOX_REPOSITORY } from './inbox.constants.js';
import { InboxController } from './inbox.controller.js';
import { PrismaInboxRepository } from './inbox-prisma.repository.js';
import { MemoryInboxRepository, type InboxRepository } from './inbox.repository.js';
import { InboxService } from './inbox.service.js';

@Module({
  imports: [PrismaModule, IdentityModule],
  controllers: [InboxController],
  providers: [
    InboxService,
    {
      provide: INBOX_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): InboxRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, InboxRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryInboxRepository(),
          createPrisma: (client) => new PrismaInboxRepository(client),
        }),
    },
  ],
  exports: [InboxService, INBOX_REPOSITORY],
})
export class InboxModule {}
