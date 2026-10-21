import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';
import { PrismaModule, PrismaService, resolvePersistenceRepository } from '../../platform/database/index.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import { IdentityModule } from '../identity/identity.module.js';
import type { IdentityRepository, MemoryIdentityRepository } from '../identity/identity.repository.js';
import { PrismaAccountDeletionRepository } from './account-deletion-prisma.repository.js';
import {
  AccountDeletionController,
  OpsAccountDeletionController,
} from './account-deletion.controller.js';
import {
  ACCOUNT_DELETION_REPOSITORY,
  MemoryAccountDeletionRepository,
  type AccountDeletionRepository,
} from './account-deletion.repository.js';
import { AccountDeletionService } from './account-deletion.service.js';

@Module({
  imports: [PrismaModule, IdentityModule, PlatformSettingsModule],
  controllers: [AccountDeletionController, OpsAccountDeletionController],
  providers: [
    AccountDeletionService,
    {
      provide: ACCOUNT_DELETION_REPOSITORY,
      inject: [PrismaService, ConfigService, IDENTITY_REPOSITORY],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
        identity: IdentityRepository,
      ): AccountDeletionRepository =>
        resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          AccountDeletionRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () =>
            new MemoryAccountDeletionRepository(identity as MemoryIdentityRepository),
          createPrisma: (client) => new PrismaAccountDeletionRepository(client),
        }),
    },
  ],
  exports: [AccountDeletionService, ACCOUNT_DELETION_REPOSITORY],
})
export class AccountDeletionModule {}
