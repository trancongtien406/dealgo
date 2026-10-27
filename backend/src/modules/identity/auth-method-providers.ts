import { Inject, Injectable, Logger, type OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isMailSenderAvailable, type MailSender } from '../../integrations/email/index.js';
import { isSmsSenderAvailable, type SmsSender } from '../../integrations/sms/index.js';
import type { AppEnv } from '../../platform/config/env.js';
import { AUTH_METHOD_POLICY_REPOSITORY, type AuthMethodName } from './auth-method.constants.js';
import type { AuthMethodPolicyRepository } from './auth-method.repository.js';
import { MAIL_SENDER, SMS_SENDER } from './identity.constants.js';

export type AuthMethodProviderEnv = Pick<AppEnv, 'WEBAUTHN_RP_ID' | 'WEBAUTHN_RP_NAME' | 'WEBAUTHN_ORIGIN'>;

/**
 * Which auth methods have a working provider behind them (DEC-PROD-052). Methods are toggled in DB
 * (AuthMethodPolicy); providers come from env. An enabled method without a provider is refused at
 * admin toggle time and blocks production boot.
 */
@Injectable()
export class AuthMethodProviderStatus {
  constructor(
    @Inject(SMS_SENDER) private readonly sms: SmsSender,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  isAvailable(method: AuthMethodName): boolean {
    return authMethodProviderAvailable(method, {
      sms: this.sms,
      mail: this.mail,
      env: {
        WEBAUTHN_RP_ID: this.config.get('WEBAUTHN_RP_ID', { infer: true }),
        WEBAUTHN_RP_NAME: this.config.get('WEBAUTHN_RP_NAME', { infer: true }),
        WEBAUTHN_ORIGIN: this.config.get('WEBAUTHN_ORIGIN', { infer: true }),
      },
    });
  }
}

export function authMethodProviderAvailable(
  method: AuthMethodName,
  deps: { sms: SmsSender; mail: MailSender; env: AuthMethodProviderEnv },
): boolean {
  switch (method) {
    case 'PHONE_SMS':
      return isSmsSenderAvailable(deps.sms);
    case 'EMAIL_LOGIN_IDENTIFIER':
      return isMailSenderAvailable(deps.mail);
    case 'PASSKEY':
      return Boolean(deps.env.WEBAUTHN_RP_ID && deps.env.WEBAUTHN_RP_NAME && deps.env.WEBAUTHN_ORIGIN);
    default: {
      const _exhaustive: never = method;
      return _exhaustive;
    }
  }
}

export const AUTH_METHOD_PROVIDER_HINT: Record<AuthMethodName, string> = {
  PHONE_SMS: 'SMS_PROVIDER=esms|speedsms with its keys',
  EMAIL_LOGIN_IDENTIFIER: 'EMAIL_PROVIDER=ses|smtp with its keys',
  PASSKEY: 'WEBAUTHN_RP_ID, WEBAUTHN_RP_NAME, WEBAUTHN_ORIGIN',
};

/** Production boot guard: every ENABLED auth method must have its provider configured. */
@Injectable()
export class AuthMethodProviderBootCheck implements OnApplicationBootstrap {
  private readonly logger = new Logger(AuthMethodProviderBootCheck.name);

  constructor(
    @Inject(AUTH_METHOD_POLICY_REPOSITORY) private readonly policies: AuthMethodPolicyRepository,
    private readonly providers: AuthMethodProviderStatus,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    const missing = await enabledMethodsWithoutProvider(this.policies, this.providers);
    if (missing.length === 0) {
      return;
    }
    const message =
      `Enabled auth method(s) without a configured provider: ${missing
        .map((method) => `${method} (needs ${AUTH_METHOD_PROVIDER_HINT[method]})`)
        .join('; ')}. Configure the provider or disable the method: npm run auth-methods -- disable <METHOD>`;
    if (this.config.get('NODE_ENV', { infer: true }) === 'production') {
      throw new Error(message);
    }
    this.logger.warn(message);
  }
}

export async function enabledMethodsWithoutProvider(
  policies: AuthMethodPolicyRepository,
  providers: Pick<AuthMethodProviderStatus, 'isAvailable'>,
): Promise<AuthMethodName[]> {
  const rows = await policies.list();
  return rows.filter((row) => row.enabled && !providers.isAvailable(row.method)).map((row) => row.method);
}
