import { Module, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { AccessAuthGuard, CustomerSessionGuard, OpsSessionGuard } from './access-auth.guard.js';
import { OpsPermissionGuard } from './ops-rbac/ops-permission.guard.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { AuthMethodProviderBootCheck, AuthMethodProviderStatus } from './auth-method-providers.js';
import { AppReviewLoginService } from './app-review-login.service.js';

import {
  MemoryAuthMethodPolicyRepository,
  type AuthMethodPolicyRepository,
} from './auth-method.repository.js';
import { AuthController } from './auth.controller.js';
import { CurrentUserService } from './current-user.service.js';
import {
  MemoryDriverPresenceRepository,
  type DriverPresenceRepository,
} from './driver-presence.repository.js';
import { DriverPresenceService } from './driver-presence.service.js';
import { DriverLocationEvents } from './driver-location-events.js';
import { EmailPasswordAuthService } from './email-password-auth.service.js';
import { EmailVerificationService } from './email-verification.service.js';
import {
  AUTH_METHOD_POLICY_REPOSITORY,
  DRIVER_PRESENCE_REPOSITORY,
  IDENTITY_REPOSITORY,
  MAIL_SENDER,
  PHONE_CHALLENGE_TTL_MS,
  SMS_SENDER,
} from './identity.constants.js';
import { MemoryIdentityRepository, type IdentityRepository } from './identity.repository.js';
import { createMailSender, type MailSender } from '../../integrations/email/index.js';
import { MeController } from './me.controller.js';
import { OpsAuthService } from './ops-auth.service.js';
import { OpsCustomersController } from './ops-customers.controller.js';
import { OpsDriversController } from './ops-drivers.controller.js';
import { OpsStaffController } from './ops-staff.controller.js';
import { OpsRoleGrantsController } from './ops-role-grants.controller.js';
import { OpsSessionsController } from './ops-sessions.controller.js';
import { OpsStaffSecurityService } from './ops-staff-security.service.js';
import { OpsUsersService } from './ops-users.service.js';
import { PasskeyService } from './passkey.service.js';
import { PasswordResetService } from './password-reset.service.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { PasswordHasher } from '../../platform/security/index.js';
import { PhoneAuthService } from './phone-auth.service.js';
import { PrismaAuthMethodPolicyRepository } from './auth-method-prisma.repository.js';
import { PrismaDriverPresenceRepository } from './driver-presence-prisma.repository.js';
import { PrismaIdentityRepository } from './identity-prisma.repository.js';
import { RoleGrantsController } from './role-grants.controller.js';
import { RoleGrantsService } from './role-grants.service.js';
import { SessionService } from './session.service.js';
import { createSmsSender, type SmsSender } from '../../integrations/sms/index.js';

@Module({
  // forwardRef: PlatformSettingsModule imports this module for its ops guards.
  imports: [PrismaModule, forwardRef(() => PlatformSettingsModule)],
  controllers: [
    AuthController,
    OpsSessionsController,
    MeController,
    RoleGrantsController,
    OpsRoleGrantsController,
    OpsCustomersController,
    OpsDriversController,
    OpsStaffController,
  ],
  providers: [
    {
      provide: IDENTITY_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): IdentityRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          IdentityRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryIdentityRepository(),
          createPrisma: (client) => new PrismaIdentityRepository(client),
        });
      },
    },
    {
      provide: SMS_SENDER,
      inject: [ConfigService],
      useFactory: (config: ConfigService<AppEnv, true>): SmsSender =>
        createSmsSender(appEnvFrom(config), Math.round(PHONE_CHALLENGE_TTL_MS / 60_000)),
    },
    {
      provide: MAIL_SENDER,
      inject: [ConfigService],
      useFactory: (config: ConfigService<AppEnv, true>): MailSender => createMailSender(appEnvFrom(config)),
    },
    {
      provide: DRIVER_PRESENCE_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): DriverPresenceRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          DriverPresenceRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: (): DriverPresenceRepository => new MemoryDriverPresenceRepository(),
          createPrisma: (client): DriverPresenceRepository =>
            new PrismaDriverPresenceRepository(client),
        });
      },
    },
    {
      provide: AUTH_METHOD_POLICY_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): AuthMethodPolicyRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          AuthMethodPolicyRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryAuthMethodPolicyRepository(),
          createPrisma: (client) => new PrismaAuthMethodPolicyRepository(client),
        });
      },
    },
    PasswordHasher,
    SessionService,
    PhoneAuthService,
    EmailVerificationService,
    EmailPasswordAuthService,
    PasskeyService,
    PasswordResetService,
    OpsAuthService,
    CurrentUserService,
    RoleGrantsService,
    OpsUsersService,
    OpsStaffSecurityService,
    DriverPresenceService,
    DriverLocationEvents,
    AuthMethodPolicyService,
    AuthMethodProviderStatus,
    AuthMethodProviderBootCheck,
    AppReviewLoginService,
    AccessAuthGuard,
    CustomerSessionGuard,
    OpsSessionGuard,
    OpsPermissionGuard,
  ],
  exports: [
    IDENTITY_REPOSITORY,
    SMS_SENDER,
    MAIL_SENDER,
    PasswordHasher,
    AUTH_METHOD_POLICY_REPOSITORY,
    AccessAuthGuard,
    CustomerSessionGuard,
    OpsSessionGuard,
    OpsPermissionGuard,
    DriverPresenceService,
    DriverLocationEvents,
    AuthMethodPolicyService,
  ],
})
export class IdentityModule {}

/** ConfigService (validated by loadEnv) → typed env view for the provider factories. */
function appEnvFrom(config: ConfigService<AppEnv, true>): AppEnv {
  return new Proxy({} as AppEnv, {
    get: (_target, key: string) => config.get(key as keyof AppEnv, { infer: true }),
  });
}
