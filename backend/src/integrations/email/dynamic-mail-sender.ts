import { Logger } from '@nestjs/common';
import type { IntegrationSettingsService } from '../../platform/integration-settings/integration-settings.service.js';
import {
  effectiveEmailConfig,
  emailConfigured,
  emailFingerprintParts,
  senderForConfig,
  type EffectiveEmailConfig,
  type MailEnv,
} from './email-config.js';
import type { EmailSuppressionRepository } from './email-suppression.repository.js';
import {
  MailDeliveryError,
  type EmailVerificationCodeMail,
  type MailSender,
  type PasswordResetCodeMail,
  type PolicyUpdateMail,
  type SignupCodeMail,
} from './mail-sender.js';
import { isMailSenderAvailable } from './mail-factory.js';
import { redactEmail } from './mail-templates.js';

export type MailStatus = {
  provider: EffectiveEmailConfig['provider'];
  /** Every field the provider needs is set. */
  configured: boolean;
  /** A test email passed with exactly the current config (mock counts as verified). */
  verified: boolean;
  fingerprint: string;
};

/**
 * MailSender that resolves its transport per send from Admin settings (DB) over env defaults,
 * so a provider change in Admin applies within the settings cache window without a restart.
 */
export class DynamicMailSender implements MailSender {
  private readonly logger = new Logger(DynamicMailSender.name);
  private cached: { fingerprint: string; sender: MailSender } | null = null;

  constructor(
    private readonly env: MailEnv,
    private readonly settings: IntegrationSettingsService,
    private readonly suppressions: EmailSuppressionRepository,
  ) {}

  /** The env bootstrap layer (Admin previews a patch against it before saving). */
  envForSettings(): MailEnv {
    return this.env;
  }

  async effective(): Promise<EffectiveEmailConfig> {
    return effectiveEmailConfig(this.env, await this.settings.values('EMAIL'));
  }

  async status(): Promise<MailStatus> {
    const values = await this.settings.values('EMAIL');
    const cfg = effectiveEmailConfig(this.env, values);
    const configured = emailConfigured(cfg);
    const fingerprint = this.settings.fingerprint(emailFingerprintParts(cfg));
    return {
      provider: cfg.provider,
      configured,
      verified: configured && (cfg.provider === 'mock' || values.testedFingerprint === fingerprint),
      fingerprint,
    };
  }

  async sendEmailVerification(input: EmailVerificationCodeMail): Promise<void> {
    await this.guard(input.email);
    await (await this.sender()).sendEmailVerification(input);
  }

  async sendPasswordResetCode(input: PasswordResetCodeMail): Promise<void> {
    await this.guard(input.email);
    await (await this.sender()).sendPasswordResetCode(input);
  }

  async sendSignupCode(input: SignupCodeMail): Promise<void> {
    await this.guard(input.email);
    await (await this.sender()).sendSignupCode(input);
  }

  async sendSignupAccountExists(input: { email: string }): Promise<void> {
    await this.guard(input.email);
    await (await this.sender()).sendSignupAccountExists(input);
  }

  async sendTestEmail(input: { email: string }): Promise<void> {
    await this.guard(input.email);
    await (await this.sender()).sendTestEmail(input);
  }

  async sendPolicyUpdate(input: PolicyUpdateMail): Promise<void> {
    await this.guard(input.email);
    await (await this.sender()).sendPolicyUpdate(input);
  }

  private async guard(email: string): Promise<void> {
    if (await this.suppressions.isSuppressed(email).catch(() => false)) {
      this.logger.warn({ msg: 'email.suppressed', to: redactEmail(email) });
      throw new MailDeliveryError('suppressed', 'dealgo');
    }
  }

  private async sender(): Promise<MailSender> {
    const cfg = await this.effective();
    const fingerprint = this.settings.fingerprint(emailFingerprintParts(cfg)) + cfg.fromName;
    if (this.cached?.fingerprint !== fingerprint) {
      this.cached = { fingerprint, sender: senderForConfig(cfg, this.env) };
    }
    return this.cached.sender;
  }
}

/** Mail status for any MailSender (tests inject plain Mock/Unavailable senders). */
export async function mailSenderStatus(sender: MailSender): Promise<Pick<MailStatus, 'configured' | 'verified'>> {
  if (sender instanceof DynamicMailSender) {
    return sender.status();
  }
  const available = isMailSenderAvailable(sender);
  return { configured: available, verified: available };
}
