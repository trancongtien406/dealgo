import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../../platform/database/index.js';
import type { AppEnv } from '../../../platform/config/index.js';
import { FoodModule } from '../../food-order/index.js';
import { IdentityModule } from '../../identity/index.js';
import { PlatformSettingsModule } from '../../../platform/settings/index.js';
import { RideModule } from '../../ride/index.js';
import { FoodChatController, RideChatController } from './chat.controller.js';
import { CHAT_REPOSITORY } from './chat.constants.js';
import { MemoryChatRepository, type ChatRepository } from './chat.repository.js';
import { ChatService } from './chat.service.js';
import { PrismaChatRepository } from './chat-prisma.repository.js';

@Module({
  imports: [PrismaModule, IdentityModule, RideModule, FoodModule, PlatformSettingsModule],
  controllers: [RideChatController, FoodChatController],
  providers: [
    ChatService,
    {
      provide: CHAT_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): ChatRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          ChatRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryChatRepository(),
          createPrisma: (client) => new PrismaChatRepository(client),
        });
      },
    },
  ],
  exports: [ChatService],
})
export class ChatModule {}
