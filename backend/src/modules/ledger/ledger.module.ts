import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { LEDGER_REPOSITORY } from './ledger.constants.js';
import { LedgerService } from './ledger.service.js';
import { MemoryLedgerRepository, type LedgerRepository } from './ledger.repository.js';
import { PrismaLedgerRepository } from './ledger-prisma.repository.js';

@Module({
  imports: [PrismaModule],
  providers: [
    LedgerService,
    {
      provide: LEDGER_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): LedgerRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          LedgerRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryLedgerRepository(),
          createPrisma: (client) => new PrismaLedgerRepository(client),
        });
      },
    },
  ],
  exports: [LedgerService, LEDGER_REPOSITORY],
})
export class LedgerModule {}
