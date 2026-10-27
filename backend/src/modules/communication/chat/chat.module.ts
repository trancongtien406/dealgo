import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../../platform/database/index.js';
import type { AppEnv } from '../../../platform/config/index.js';
import { FoodModule } from '../../food-order/index.js';
import { AccountSettingsModule } from '../../account-settings/index.js';
import { PushModule } from '../../../integrations/push/push.module.js';
import { IdentityModule } from '../../identity/index.js';
import { PlatformSettingsModule } from '../../../platform/settings/index.js';
import { RideModule } from '../../ride/index.js';
import { RealtimeModule } from '../realtime/realtime.module.js';
import { FoodChatController, RideChatController } from './chat.controller.js';
import { OpsChatReviewController } from './chat-review.controller.js';
import { ChatReviewService } from './chat-review.service.js';
import { CHAT_REPOSITORY } from './chat.constants.js';
import { MemoryChatRepository, type ChatRepository } from './chat.repository.js';
import { ChatService } from './chat.service.js';
import { PrismaChatRepository } from './chat-prisma.repository.js';
import { chatCipherFromEnv } from './chat-cipher.js';

@Module({
  imports: [PrismaModule, IdentityModule, RideModule, FoodModule, PlatformSettingsModule, PushModule, AccountSettingsModule, RealtimeModule],
  controllers: [RideChatController, FoodChatController, OpsChatReviewController],
  providers: [
    ChatService,
    ChatReviewService,

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
          createPrisma: (client) =>
            new PrismaChatRepository(
              client,
              chatCipherFromEnv({
                NODE_ENV: config.get('NODE_ENV', { infer: true }),
                CHAT_ENCRYPTION_KEY: config.get('CHAT_ENCRYPTION_KEY', { infer: true }),
                CHAT_ENCRYPTION_KEY_VERSION: config.get('CHAT_ENCRYPTION_KEY_VERSION', {
                  infer: true,
                }),
                CHAT_ENCRYPTION_PREVIOUS_KEYS: config.get('CHAT_ENCRYPTION_PREVIOUS_KEYS', {
                  infer: true,
                }),
              }),
            ),
        });
      },
    },
  ],
  exports: [ChatService],
})
export class ChatModule {}
