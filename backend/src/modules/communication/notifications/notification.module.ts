import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../../platform/config/index.js';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../../platform/database/index.js';
import { IdentityModule } from '../../identity/index.js';
import {
  NOTIFICATION_REPOSITORY,
  OPS_NOTIFICATION_REPOSITORY,
} from './notification.constants.js';
import { NotificationController } from './notification.controller.js';
import { PublicCmsController } from './public-cms.controller.js';
import {
  MemoryNotificationRepository,
  PrismaNotificationRepository,
  type NotificationRepository,
} from './notification.repository.js';
import { NotificationService } from './notification.service.js';

@Module({
  imports: [PrismaModule, IdentityModule],
  controllers: [NotificationController, PublicCmsController],
  providers: [
    NotificationService,
    {
      provide: NOTIFICATION_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): NotificationRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          NotificationRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryNotificationRepository(),
          createPrisma: (client) => new PrismaNotificationRepository(client),
        });
      },
    },
  ],
  exports: [
    NotificationService,
    NOTIFICATION_REPOSITORY,
    OPS_NOTIFICATION_REPOSITORY,
  ],
})
export class NotificationModule {}
