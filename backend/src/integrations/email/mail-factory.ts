import type { AppEnv } from '../../platform/config/env.js';
import { MockMailSender, UnavailableMailSender, type MailSender } from './mail-sender.js';
import { SesMailSender } from './ses-mail-sender.js';
import { SmtpMailSender } from './smtp-mail-sender.js';

export const DEFAULT_EMAIL_FROM = 'DealGo <noreply@dealgo.local>';

export type MailEnv = Pick<
  AppEnv,
  | 'NODE_ENV'
  | 'EMAIL_PROVIDER'
  | 'EMAIL_FROM'
  | 'SMTP_URL'
  | 'SMTP_FROM'
  | 'SES_REGION'
  | 'SES_ACCESS_KEY_ID'
  | 'SES_SECRET_ACCESS_KEY'
  | 'SES_CONFIGURATION_SET'
  | 'EMAIL_HTTP_TIMEOUT_MS'
>;

/**
 * EMAIL_PROVIDER → adapter. `smtp` (any SMTP: SES SMTP, Brevo, …), `ses` (SES v2 API), mock outside
 * production. `none`/missing keys → Unavailable (EMAIL_LOGIN_IDENTIFIER cannot be enabled).
 */
export function createMailSender(env: MailEnv): MailSender {
  const provider = env.EMAIL_PROVIDER;
  const from = env.EMAIL_FROM || env.SMTP_FROM || DEFAULT_EMAIL_FROM;
  if (provider === 'smtp' && env.SMTP_URL) {
    return new SmtpMailSender(env.SMTP_URL, from);
  }
  if (provider === 'ses' && env.SES_REGION && env.SES_ACCESS_KEY_ID && env.SES_SECRET_ACCESS_KEY) {
    return new SesMailSender({
      region: env.SES_REGION,
      accessKeyId: env.SES_ACCESS_KEY_ID,
      secretAccessKey: env.SES_SECRET_ACCESS_KEY,
      from,
      configurationSet: env.SES_CONFIGURATION_SET,
      timeoutMs: env.EMAIL_HTTP_TIMEOUT_MS,
    });
  }
  if ((provider === 'mock' || provider === undefined) && env.NODE_ENV !== 'production') {
    return new MockMailSender(env.NODE_ENV);
  }
  return new UnavailableMailSender();
}

export function isMailSenderAvailable(sender: MailSender): boolean {
  return !(sender instanceof UnavailableMailSender);
}
