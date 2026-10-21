import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';
import {
  PrismaModule,
  PrismaService,
  resolvePersistenceRepository,
} from '../../platform/database/index.js';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { LedgerModule } from '../ledger/index.js';
import { EARNINGS_REPOSITORY } from './earnings.constants.js';
import { PrismaEarningsRepository } from './earnings-prisma.repository.js';
import { MemoryEarningsRepository, type EarningsRepository } from './earnings.repository.js';
import { EarningsService } from './earnings.service.js';

@Module({
  imports: [PrismaModule, PlatformSettingsModule, LedgerModule],
  providers: [
    EarningsService,
    {
      provide: EARNINGS_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): EarningsRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, EarningsRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryEarningsRepository(),
          createPrisma: (client) => new PrismaEarningsRepository(client),
        }),
    },
  ],
  exports: [EarningsService],
})
export class EarningsModule {}
