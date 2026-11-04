import { Inject, Injectable, Logger, Optional, type OnApplicationBootstrap } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { mailSenderStatus, type MailSender } from '../../integrations/email/index.js';
import { DynamicSmsSender, isSmsSenderAvailable, type SmsSender } from '../../integrations/sms/index.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import type { AppEnv } from '../../platform/config/env.js';
import { AUTH_METHOD_POLICY_REPOSITORY, type AuthMethodName } from './auth-method.constants.js';
import type { AuthMethodPolicyRepository } from './auth-method.repository.js';
import { MAIL_SENDER, SMS_SENDER } from './identity.constants.js';

export type AuthMethodProviderEnv = Pick<AppEnv, 'WEBAUTHN_RP_ID' | 'WEBAUTHN_RP_NAME' | 'WEBAUTHN_ORIGIN'>;

/**
 * `enable`: may an Admin switch the method on (email also needs a passed test email for the current
 * config). `boot`: is the provider configured at all (production refuses to start otherwise).
 */
export type ProviderCheckPurpose = 'enable' | 'boot';

/**
 * Which auth methods have a working provider behind them (DEC-PROD-052). Methods are toggled in DB
 * (AuthMethodPolicy); SMS/passkey providers come from env, email from Admin › Email over env.
 */
@Injectable()
export class AuthMethodProviderStatus {
  constructor(
    @Inject(SMS_SENDER) private readonly sms: SmsSender,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    private readonly config: ConfigService<AppEnv, true>,
    @Optional() private readonly platformSettings?: PlatformSettingsService,
  ) {}

  async isAvailable(method: AuthMethodName, purpose: ProviderCheckPurpose = 'enable'): Promise<boolean> {
    let rpId = this.config.get('WEBAUTHN_RP_ID', { infer: true });
    let rpName = this.config.get('WEBAUTHN_RP_NAME', { infer: true });
    let origin = this.config.get('WEBAUTHN_ORIGIN', { infer: true });

    if (this.platformSettings) {
      rpId = (await this.platformSettings.getString('WEBAUTHN_RP_ID')) || rpId;
      rpName = (await this.platformSettings.getString('WEBAUTHN_RP_NAME')) || rpName;
      origin = (await this.platformSettings.getString('WEBAUTHN_ORIGIN')) || origin;
    }

    return authMethodProviderAvailable(method, purpose, {
      sms: this.sms,
      mail: this.mail,
      env: {
        WEBAUTHN_RP_ID: rpId,
        WEBAUTHN_RP_NAME: rpName,
        WEBAUTHN_ORIGIN: origin,
      },
    });
  }
}

export async function authMethodProviderAvailable(
  method: AuthMethodName,
  purpose: ProviderCheckPurpose,
  deps: { sms: SmsSender; mail: MailSender; env: AuthMethodProviderEnv },
): Promise<boolean> {
  switch (method) {
    case 'PHONE_SMS':
      if (deps.sms instanceof DynamicSmsSender) {
        return deps.sms.isConfigured();
      }
      return isSmsSenderAvailable(deps.sms);
    case 'EMAIL_LOGIN_IDENTIFIER': {
      const status = await mailSenderStatus(deps.mail);
      return purpose === 'boot' ? status.configured : status.verified;
    }
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
  EMAIL_LOGIN_IDENTIFIER: 'Admin › Email (Gmail SMTP or Amazon SES) configured and a test email passed',
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
  const missing: AuthMethodName[] = [];
  for (const row of rows) {
    if (row.enabled && !(await providers.isAvailable(row.method, 'boot'))) missing.push(row.method);
  }
  return missing;
}
