import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';
import { PrismaModule, PrismaService, resolvePersistenceRepository } from '../../platform/database/index.js';
import { IdentityModule } from '../identity/index.js';
import { OpsPublicPagesController, PublicPagesController } from './public-pages.controller.js';
import {
  MemoryPublicPagesRepository,
  PrismaPublicPagesRepository,
  type PublicPagesRepository,
} from './public-pages.repository.js';
import { PublicPagesService } from './public-pages.service.js';
import { PUBLIC_PAGES_REPOSITORY } from './public-pages.types.js';

@Module({
  imports: [PrismaModule, IdentityModule],
  controllers: [PublicPagesController, OpsPublicPagesController],
  providers: [
    PublicPagesService,
    {
      provide: PUBLIC_PAGES_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): PublicPagesRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, PublicPagesRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryPublicPagesRepository(),
          createPrisma: (client) => new PrismaPublicPagesRepository(client),
        }),
    },
  ],
  exports: [PublicPagesService],
})
export class PublicPagesModule {}
