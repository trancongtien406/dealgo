import type { AppEnv } from '../../platform/config/env.js';
import type { EmailConfigField, EmailSecretField } from '../../platform/integration-settings/integration-settings.constants.js';
import type { IntegrationValues } from '../../platform/integration-settings/integration-settings.service.js';
import { MockMailSender, UnavailableMailSender, type MailSender } from './mail-sender.js';
import { SesMailSender } from './ses-mail-sender.js';
import { parseSmtpUrl, SmtpMailSender } from './smtp-mail-sender.js';

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

/** What Admin can choose. `mock` only appears when env selects it outside production. */
export type EmailProviderChoice = 'smtp' | 'ses' | 'disabled';
export type EmailProvider = EmailProviderChoice | 'mock';

export const EMAIL_PROVIDER_CHOICES: readonly EmailProviderChoice[] = ['smtp', 'ses', 'disabled'];

/** Gmail SMTP is the default transport (STARTTLS 587 + App Password). */
export const GMAIL_SMTP_HOST = 'smtp.gmail.com';
export const GMAIL_SMTP_PORT = 587;
export const DEFAULT_FROM_NAME = 'DealGo';

export type FieldSource = 'admin' | 'env' | 'default' | 'unset';

export type EffectiveEmailConfig = {
  provider: EmailProvider;
  fromName: string;
  fromAddress: string;
  smtp: { host: string; port: number; user: string; password: string; secure: boolean };
  ses: {
    region: string;
    accessKeyId: string;
    secretAccessKey: string;
    configurationSet: string;
    snsTopicArn: string;
  };
  sources: Record<EmailConfigField | EmailSecretField, FieldSource>;
};

type EnvDefaults = Partial<Record<EmailConfigField | EmailSecretField, string>>;

/** Env is the bootstrap layer; Admin (DB) values override field by field. */
export function effectiveEmailConfig(env: MailEnv, admin: Pick<IntegrationValues, 'config' | 'secrets'>): EffectiveEmailConfig {
  const defaults = envDefaults(env);
  const sources = {} as EffectiveEmailConfig['sources'];
  const pick = (field: EmailConfigField | EmailSecretField, fallback = ''): string => {
    const adminValue = (admin.config as Record<string, string>)[field] ?? (admin.secrets as Record<string, string>)[field];
    if (adminValue) {
      sources[field] = 'admin';
      return adminValue;
    }
    const envValue = defaults[field];
    if (envValue) {
      sources[field] = 'env';
      return envValue;
    }
    sources[field] = fallback ? 'default' : 'unset';
    return fallback;
  };

  const rawProvider = pick('provider', env.NODE_ENV === 'production' ? 'disabled' : 'mock');
  const provider: EmailProvider =
    rawProvider === 'smtp' || rawProvider === 'ses' || rawProvider === 'disabled'
      ? rawProvider
      : rawProvider === 'mock' && env.NODE_ENV !== 'production'
        ? 'mock'
        : 'disabled';
  const port = Number(pick('smtpPort', String(GMAIL_SMTP_PORT)));
  return {
    provider,
    fromName: pick('fromName', DEFAULT_FROM_NAME),
    fromAddress: pick('fromAddress'),
    smtp: {
      host: pick('smtpHost', GMAIL_SMTP_HOST),
      port: Number.isInteger(port) && port > 0 ? port : GMAIL_SMTP_PORT,
      user: pick('smtpUser'),
      password: pick('smtpPassword'),
      secure: pick('smtpSecure', 'false') === 'true',
    },
    ses: {
      region: pick('sesRegion', 'ap-southeast-1'),
      accessKeyId: pick('sesAccessKeyId'),
      secretAccessKey: pick('sesSecretAccessKey'),
      configurationSet: pick('sesConfigurationSet'),
      snsTopicArn: pick('sesSnsTopicArn'),
    },
    sources,
  };
}

function envDefaults(env: MailEnv): EnvDefaults {
  const out: EnvDefaults = {};
  const provider = env.EMAIL_PROVIDER;
  if (provider === 'smtp' || provider === 'ses') out.provider = provider;
  else if (provider === 'none') out.provider = 'disabled';
  else if (provider === 'mock') out.provider = 'mock';

  const from = parseFromHeader(env.EMAIL_FROM || env.SMTP_FROM || '');
  if (from.name) out.fromName = from.name;
  if (from.address) out.fromAddress = from.address;

  if (env.SMTP_URL) {
    try {
      const target = parseSmtpUrl(env.SMTP_URL);
      out.smtpHost = target.host;
      out.smtpPort = String(target.port);
      out.smtpSecure = String(target.secure);
      if (target.user) out.smtpUser = target.user;
      if (target.password) out.smtpPassword = target.password;
    } catch {
      // Invalid SMTP_URL: treated as unset.
    }
  }
  if (env.SES_REGION) out.sesRegion = env.SES_REGION;
  if (env.SES_ACCESS_KEY_ID) out.sesAccessKeyId = env.SES_ACCESS_KEY_ID;
  if (env.SES_SECRET_ACCESS_KEY) out.sesSecretAccessKey = env.SES_SECRET_ACCESS_KEY;
  if (env.SES_CONFIGURATION_SET) out.sesConfigurationSet = env.SES_CONFIGURATION_SET;
  return out;
}

/** "DealGo <noreply@x.vn>" | "noreply@x.vn" → parts. */
export function parseFromHeader(raw: string): { name: string; address: string } {
  const value = raw.trim();
  const match = value.match(/^(.*)<([^>]+)>$/);
  if (match) {
    return { name: match[1]!.trim().replace(/^"|"$/g, ''), address: match[2]!.trim() };
  }
  return { name: '', address: value };
}

export function formatFromHeader(name: string, address: string): string {
  const safeName = name.replace(/["<>\r\n]/g, '').trim();
  return safeName ? `${safeName} <${address}>` : address;
}

const EMAIL_RE = /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/;

export function isEmailAddress(value: string): boolean {
  return EMAIL_RE.test(value);
}

/** Every field the chosen provider needs is present (sending may still fail; see `verified`). */
export function emailConfigured(cfg: EffectiveEmailConfig): boolean {
  switch (cfg.provider) {
    case 'mock':
      return true;
    case 'disabled':
      return false;
    case 'smtp':
      return Boolean(cfg.smtp.host && isEmailAddress(cfg.fromAddress) && (!cfg.smtp.user || cfg.smtp.password));
    case 'ses':
      return Boolean(
        cfg.ses.region && cfg.ses.accessKeyId && cfg.ses.secretAccessKey && isEmailAddress(cfg.fromAddress),
      );
  }
}

/** The fields that make a delivery path; a passed test is tied to exactly these. */
export function emailFingerprintParts(cfg: EffectiveEmailConfig): unknown {
  const base = { provider: cfg.provider, from: cfg.fromAddress };
  if (cfg.provider === 'smtp') return { ...base, smtp: cfg.smtp };
  if (cfg.provider === 'ses') {
    const { snsTopicArn: _ignored, ...ses } = cfg.ses;
    return { ...base, ses };
  }
  return base;
}

export function buildSmtpUrl(smtp: EffectiveEmailConfig['smtp']): string {
  const scheme = smtp.secure ? 'smtps' : 'smtp';
  const auth = smtp.user ? `${encodeURIComponent(smtp.user)}:${encodeURIComponent(smtp.password)}@` : '';
  return `${scheme}://${auth}${smtp.host}:${smtp.port}`;
}

export function senderForConfig(cfg: EffectiveEmailConfig, env: Pick<MailEnv, 'NODE_ENV' | 'EMAIL_HTTP_TIMEOUT_MS'>): MailSender {
  if (!emailConfigured(cfg)) return new UnavailableMailSender();
  const from = formatFromHeader(cfg.fromName, cfg.fromAddress);
  switch (cfg.provider) {
    case 'mock':
      return new MockMailSender(env.NODE_ENV);
    case 'smtp':
      return new SmtpMailSender(buildSmtpUrl(cfg.smtp), from, env.EMAIL_HTTP_TIMEOUT_MS);
    case 'ses':
      return new SesMailSender({
        region: cfg.ses.region,
        accessKeyId: cfg.ses.accessKeyId,
        secretAccessKey: cfg.ses.secretAccessKey,
        from,
        configurationSet: cfg.ses.configurationSet || undefined,
        timeoutMs: env.EMAIL_HTTP_TIMEOUT_MS,
      });
    default:
      return new UnavailableMailSender();
  }
}
