import { Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { IdentityModule } from '../../modules/identity/identity.module.js';
import { PrismaModule } from '../../platform/database/prisma.module.js';
import {
  ApnsVoipPushSender,
  DisabledVoipPushSender,
  VOIP_PUSH_SENDER,
  apnsOrigin,
  apnsVoipEnvFrom,
  apnsVoipStatusFrom,
  type VoipPushSender,
} from './apns-voip-sender.js';
import { resolveFcmCredentials } from './fcm-credentials.js';
import { FcmPushSender } from './fcm-push-sender.js';
import { PUSH_SENDER } from './push.constants.js';
import { PushTokenService } from './push-token.service.js';
import { PushTokensController } from './push-tokens.controller.js';
import {
  MockPushSender,
  UnavailablePushSender,
  type PushSender,
} from './push-sender.js';

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
        if (
          (provider === 'mock' || provider === undefined) &&
          nodeEnv !== 'production'
        ) {
          return new MockPushSender(nodeEnv);
        }
        if (provider === 'fcm') {
          const credentials = fcmCredentialsFromConfig(config);
          if (credentials) {
            return new FcmPushSender(
              credentials,
              (userId, skipPlatforms) =>
                tokens.tokensForUser(userId, skipPlatforms),
              fetch,
              (token) => tokens.forget(token),
            );
          }
        }
        // fcm without keys, unknown provider, or production without fcm → unavailable.
        return new UnavailablePushSender();
      },
    },
    {
      provide: VOIP_PUSH_SENDER,
      inject: [ConfigService, PushTokenService],
      useFactory: (
        config: ConfigService<AppEnv, true>,
        tokens: PushTokenService,
      ): VoipPushSender => {
        const logger = new Logger('VoipPush');
        const status = apnsVoipStatusFrom(
          apnsVoipEnvFrom((key) => config.get(key, { infer: true })),
        );
        if (!status.config) {
          // iOS still rings through the normal FCM alert push; Android never uses VoIP.
          const line = `iOS VoIP (PushKit) pushes off: ${status.detail}. Incoming calls ring via the FCM alert.`;
          if (status.reason === 'missing') {
            logger.log(line);
          } else {
            logger.warn(line);
          }
          return new DisabledVoipPushSender();
        }
        const apns = status.config;
        logger.log(
          `iOS VoIP pushes on: key ${apns.keyId}, team ${apns.teamId}, topic ${apns.bundleId}.voip, ${apnsOrigin(apns)}`,
        );
        if (
          apns.sandbox &&
          config.get('NODE_ENV', { infer: true }) === 'production'
        ) {
          logger.warn(
            'APNs sandbox host with NODE_ENV=production: TestFlight / App Store builds need APNS_ENV=production',
          );
        }
        return new ApnsVoipPushSender(
          apns,
          (userId) => tokens.voipTokensForUser(userId),
          (token) => tokens.forget(token),
        );
      },
    },
  ],
  exports: [PUSH_SENDER, VOIP_PUSH_SENDER, PushTokenService],
})
export class PushModule {}
