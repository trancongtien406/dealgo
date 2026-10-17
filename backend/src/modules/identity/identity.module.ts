import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { AccessAuthGuard, CustomerSessionGuard, OpsSessionGuard } from './access-auth.guard.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
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
import { EmailVerificationService } from './email-verification.service.js';
import {
  AUTH_METHOD_POLICY_REPOSITORY,
  DRIVER_PRESENCE_REPOSITORY,
  IDENTITY_REPOSITORY,
  MAIL_SENDER,
  SMS_SENDER,
} from './identity.constants.js';
import { MemoryIdentityRepository, type IdentityRepository } from './identity.repository.js';
import { MockMailSender, UnavailableMailSender, type MailSender, SmtpMailSender } from '../../integrations/email/index.js';
import { MeController } from './me.controller.js';
import { OpsAuthService } from './ops-auth.service.js';
import { OpsCustomersController } from './ops-customers.controller.js';
import { OpsDriversController } from './ops-drivers.controller.js';
import { OpsStaffController } from './ops-staff.controller.js';
import { OpsRoleGrantsController } from './ops-role-grants.controller.js';
import { OpsSessionsController } from './ops-sessions.controller.js';
import { OpsUsersService } from './ops-users.service.js';
import { PasskeyService } from './passkey.service.js';
import { PasswordHasher } from '../../platform/security/index.js';
import { PhoneAuthService } from './phone-auth.service.js';
import { PrismaAuthMethodPolicyRepository } from './auth-method-prisma.repository.js';
import { PrismaDriverPresenceRepository } from './driver-presence-prisma.repository.js';
import { PrismaIdentityRepository } from './identity-prisma.repository.js';
import { RoleGrantsController } from './role-grants.controller.js';
import { RoleGrantsService } from './role-grants.service.js';
import { SessionService } from './session.service.js';
import { MockSmsSender, UnavailableSmsSender, type SmsSender } from '../../integrations/sms/sms-sender.js';

@Module({
  imports: [PrismaModule],
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
      useFactory: (config: ConfigService<AppEnv, true>): SmsSender => {
        const provider = config.get('SMS_PROVIDER', { infer: true });
        const nodeEnv = config.get('NODE_ENV', { infer: true });
        if ((provider === 'mock' || provider === undefined) && nodeEnv !== 'production') {
          return new MockSmsSender(nodeEnv);
        }
        return new UnavailableSmsSender();
      },
    },
    {
      provide: MAIL_SENDER,
      inject: [ConfigService],
      useFactory: (config: ConfigService<AppEnv, true>): MailSender => {
        const provider = config.get('EMAIL_PROVIDER', { infer: true });
        const nodeEnv = config.get('NODE_ENV', { infer: true });
        if (provider === 'smtp') {
          const smtpUrl = config.get('SMTP_URL', { infer: true });
          if (!smtpUrl) {
            return new UnavailableMailSender();
          }
          const from =
            config.get('SMTP_FROM', { infer: true })?.trim() || 'DealGo <noreply@dealgo.local>';
          return new SmtpMailSender(smtpUrl, from);
        }
        if ((provider === 'mock' || provider === undefined) && nodeEnv !== 'production') {
          return new MockMailSender(nodeEnv);
        }
        return new UnavailableMailSender();
      },
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
    PasskeyService,
    OpsAuthService,
    CurrentUserService,
    RoleGrantsService,
    OpsUsersService,
    DriverPresenceService,
    AuthMethodPolicyService,
    AccessAuthGuard,
    CustomerSessionGuard,
    OpsSessionGuard,
  ],
  exports: [
    IDENTITY_REPOSITORY,
    AUTH_METHOD_POLICY_REPOSITORY,
    AccessAuthGuard,
    CustomerSessionGuard,
    OpsSessionGuard,
    DriverPresenceService,
    AuthMethodPolicyService,
  ],
})
export class IdentityModule {}
