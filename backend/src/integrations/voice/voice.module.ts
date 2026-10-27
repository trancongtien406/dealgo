import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { AccountSettingsModule } from '../../modules/account-settings/account-settings.module.js';
import { ChatModule } from '../../modules/communication/chat/chat.module.js';
import { RealtimeModule } from '../../modules/communication/realtime/realtime.module.js';
import { FoodModule } from '../../modules/food-order/food.module.js';
import { IdentityModule } from '../../modules/identity/identity.module.js';
import { RideModule } from '../../modules/ride/ride.module.js';
import { PrismaModule, PrismaService, resolvePersistenceRepository } from '../../platform/database/index.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { PushModule } from '../push/push.module.js';
import { VOICE_CALL_REPOSITORY, VOICE_PORT } from './voice.constants.js';
import { FoodVoiceController, RideVoiceController, VoiceCallController } from './voice.controller.js';
import { MemoryVoiceCallRepository, type VoiceCallRepository } from './voice-call.repository.js';
import { PrismaVoiceCallRepository } from './voice-call-prisma.repository.js';
import {
  LiveKitVoicePort,
  MockVoicePort,
  UnavailableVoicePort,
  type VoicePort,
} from './voice-port.js';
import { VoiceService } from './voice.service.js';

/** env.ts already rejects a half-configured `livekit` provider; this only picks the port. */
export function createVoicePort(config: ConfigService<AppEnv, true>): VoicePort {
  const provider = config.get('VOICE_PROVIDER', { infer: true });
  const nodeEnv = config.get('NODE_ENV', { infer: true });
  if (provider === 'mock' && nodeEnv !== 'production') {
    return new MockVoicePort(nodeEnv);
  }
  const url = config.get('LIVEKIT_URL', { infer: true });
  const apiKey = config.get('LIVEKIT_API_KEY', { infer: true });
  const apiSecret = config.get('LIVEKIT_API_SECRET', { infer: true });
  if (provider === 'livekit' && url && apiKey && apiSecret) {
    return new LiveKitVoicePort({ url, apiKey, apiSecret });
  }
  // Unset or `none`: calls fail closed with VOICE_UNAVAILABLE.
  return new UnavailableVoicePort();
}

@Module({
  imports: [
    PrismaModule,
    IdentityModule,
    RideModule,
    FoodModule,
    PlatformSettingsModule,
    RealtimeModule,
    ChatModule,
    PushModule,
    AccountSettingsModule,
  ],
  controllers: [RideVoiceController, FoodVoiceController, VoiceCallController],
  providers: [
    VoiceService,
    {
      provide: VOICE_PORT,
      inject: [ConfigService],
      useFactory: createVoicePort,
    },
    {
      provide: VOICE_CALL_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): VoiceCallRepository =>
        resolvePersistenceRepository<NonNullable<ReturnType<PrismaService['db']>>, VoiceCallRepository>({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryVoiceCallRepository(),
          createPrisma: (client) => new PrismaVoiceCallRepository(client),
        }),
    },
  ],
  exports: [VoiceService, VOICE_PORT],
})
export class VoiceModule {}
