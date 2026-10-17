import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { FoodModule } from '../../modules/food-order/food.module.js';
import { IdentityModule } from '../../modules/identity/identity.module.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { PrismaModule } from '../../platform/database/prisma.module.js';
import { RideModule } from '../../modules/ride/ride.module.js';
import { VOICE_PORT } from './voice.constants.js';
import { FoodVoiceController, RideVoiceController } from './voice.controller.js';
import {
  LiveKitVoicePort,
  MockVoicePort,
  UnavailableVoicePort,
  type VoicePort,
} from './voice-port.js';
import { VoiceService } from './voice.service.js';

function hasLiveKitKeys(config: ConfigService<AppEnv, true>): boolean {
  return Boolean(
    config.get('LIVEKIT_URL', { infer: true }) &&
      config.get('LIVEKIT_API_KEY', { infer: true }) &&
      config.get('LIVEKIT_API_SECRET', { infer: true }),
  );
}

@Module({
  imports: [PrismaModule, IdentityModule, RideModule, FoodModule, PlatformSettingsModule],
  controllers: [RideVoiceController, FoodVoiceController],
  providers: [
    VoiceService,
    {
      provide: VOICE_PORT,
      inject: [ConfigService],
      useFactory: (config: ConfigService<AppEnv, true>): VoicePort => {
        const provider = config.get('VOICE_PROVIDER', { infer: true });
        const nodeEnv = config.get('NODE_ENV', { infer: true });
        if ((provider === 'mock' || provider === undefined) && nodeEnv !== 'production') {
          return new MockVoicePort(nodeEnv);
        }
        if (provider === 'livekit' && hasLiveKitKeys(config)) {
          return new LiveKitVoicePort({
            url: config.get('LIVEKIT_URL', { infer: true })!,
            apiKey: config.get('LIVEKIT_API_KEY', { infer: true })!,
            apiSecret: config.get('LIVEKIT_API_SECRET', { infer: true })!,
          });
        }
        return new UnavailableVoicePort();
      },
    },
  ],
  exports: [VoiceService, VOICE_PORT],
})
export class VoiceModule {}
