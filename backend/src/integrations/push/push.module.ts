import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { IdentityModule } from '../../modules/identity/identity.module.js';
import { PrismaModule } from '../../platform/database/prisma.module.js';
import { resolveFcmCredentials } from './fcm-credentials.js';
import { FcmPushSender } from './fcm-push-sender.js';
import { PUSH_SENDER } from './push.constants.js';
import { PushTokenService } from './push-token.service.js';
import { PushTokensController } from './push-tokens.controller.js';
import { MockPushSender, UnavailablePushSender, type PushSender } from './push-sender.js';

function fcmCredentialsFromConfig(config: ConfigService<AppEnv, true>) {
  return resolveFcmCredentials({
    projectId: config.get('FCM_PROJECT_ID', { infer: true }),
    clientEmail: config.get('FCM_CLIENT_EMAIL', { infer: true }),
    privateKey: config.get('FCM_PRIVATE_KEY', { infer: true }),
    serviceAccountPath: config.get('FCM_SERVICE_ACCOUNT_PATH', { infer: true }),
    googleApplicationCredentials: config.get('GOOGLE_APPLICATION_CREDENTIALS', {
      infer: true,
    }),
  });
}

@Module({
  imports: [PrismaModule, IdentityModule],
  controllers: [PushTokensController],
  providers: [
    PushTokenService,
    {
      provide: PUSH_SENDER,
      inject: [ConfigService, PushTokenService],
      useFactory: (
        config: ConfigService<AppEnv, true>,
        tokens: PushTokenService,
      ): PushSender => {
        const provider = config.get('PUSH_PROVIDER', { infer: true });
        const nodeEnv = config.get('NODE_ENV', { infer: true });
        if ((provider === 'mock' || provider === undefined) && nodeEnv !== 'production') {
          return new MockPushSender(nodeEnv);
        }
        if (provider === 'fcm') {
          const credentials = fcmCredentialsFromConfig(config);
          if (credentials) {
            return new FcmPushSender(credentials, (userId) => tokens.tokensForUser(userId));
          }
        }
        // fcm without keys, unknown provider, or production without fcm → unavailable.
        return new UnavailablePushSender();
      },
    },
  ],
  exports: [PUSH_SENDER, PushTokenService],
})
export class PushModule {}
