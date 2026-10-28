import { Inject, Injectable } from '@nestjs/common';
import {
  DynamicMailSender,
  EMAIL_PROVIDER_CHOICES,
  effectiveEmailConfig,
  emailConfigured,
  isEmailAddress,
  MailDeliveryError,
  type EffectiveEmailConfig,
  type MailSender,
} from '../../integrations/email/index.js';
import {
  INTEGRATION_FIELDS,
  integrationError,
  IntegrationSettingsService,
  MapKeysService,
  type IntegrationPatch,
  type IntegrationValues,
  type MapsSecretField,
} from '../../platform/integration-settings/index.js';
import { MAIL_SENDER } from '../identity/identity.constants.js';
import { AUTH_METHOD_POLICY_REPOSITORY } from '../identity/auth-method.constants.js';
import type { AuthMethodPolicyRepository } from '../identity/auth-method.repository.js';
import type { PutEmailSettingsDto, PutMapKeysDto } from './integrations-admin.dto.js';

export const INTEGRATIONS_FETCH = Symbol('INTEGRATIONS_FETCH');
export type IntegrationsFetch = (url: string, init?: { signal?: AbortSignal }) => Promise<{
  ok: boolean;
  status: number;
  json(): Promise<unknown>;
}>;

const KEY_TEST_TIMEOUT_MS = 6000;
const SES_REGION = /^[a-z]{2}(-gov)?-[a-z]+-\d$/;
const SNS_TOPIC_ARN = /^arn:aws(-cn)?:sns:[a-z0-9-]+:\d{12}:[A-Za-z0-9_-]+$/;

export type EmailSettingsView = {
  canStoreSecrets: boolean;
  secretsUnreadable: boolean;
  providers: readonly string[];
  provider: EffectiveEmailConfig['provider'];
  fromName: string;
  fromAddress: string;
  smtp: { host: string; port: number; user: string; secure: boolean; passwordSet: boolean };
  ses: {
    region: string;
    configurationSet: string;
    snsTopicArn: string;
    accessKeyIdSet: boolean;
    secretAccessKeySet: boolean;
  };
  sources: EffectiveEmailConfig['sources'];
  status: { configured: boolean; verified: boolean; testedAt: string | null };
  updatedAt: string | null;
  /** SNS HTTPS subscription path for SES bounce/complaint notifications. */
  webhookPath: string;
};

export type MapKeysView = {
  canStoreSecrets: boolean;
  secretsUnreadable: boolean;
  keys: Array<{ field: MapsSecretField; set: boolean; source: 'admin' | 'env' | 'unset'; hint: string | null }>;
  testedAt: string | null;
  updatedAt: string | null;
};

export type MapKeyTestResult = { field: MapsSecretField; ok: boolean; detail: string };

@Injectable()
export class IntegrationsAdminService {
  constructor(
    private readonly settings: IntegrationSettingsService,
    private readonly mail: DynamicMailSender,
    @Inject(MAIL_SENDER) private readonly mailSender: MailSender,
    private readonly mapKeys: MapKeysService,
    @Inject(AUTH_METHOD_POLICY_REPOSITORY) private readonly authMethods: AuthMethodPolicyRepository,
    @Inject(INTEGRATIONS_FETCH) private readonly fetcher: IntegrationsFetch,
  ) {}

  // ── Email ────────────────────────────────────────────────────────────────

  async emailView(): Promise<EmailSettingsView> {
    const values = await this.settings.values('EMAIL');
    const cfg = await this.mail.effective();
    const status = await this.mail.status();
    return {
      canStoreSecrets: this.settings.canStoreSecrets(),
      secretsUnreadable: values.secretsUnreadable,
      providers: EMAIL_PROVIDER_CHOICES,
      provider: cfg.provider,
      fromName: cfg.fromName,
      fromAddress: cfg.fromAddress,
      smtp: {
        host: cfg.smtp.host,
        port: cfg.smtp.port,
        user: cfg.smtp.user,
        secure: cfg.smtp.secure,
        passwordSet: Boolean(cfg.smtp.password),
      },
      ses: {
        region: cfg.ses.region,
        configurationSet: cfg.ses.configurationSet,
        snsTopicArn: cfg.ses.snsTopicArn,
        accessKeyIdSet: Boolean(cfg.ses.accessKeyId),
        secretAccessKeySet: Boolean(cfg.ses.secretAccessKey),
      },
      sources: cfg.sources,
      status: {
        configured: status.configured,
        verified: status.verified,
        testedAt: status.verified && values.testedAt ? values.testedAt.toISOString() : null,
      },
      updatedAt: values.updatedAt?.toISOString() ?? null,
      webhookPath: '/v1/webhooks/ses',
    };
  }

  async updateEmail(body: PutEmailSettingsDto, actorUserId: string): Promise<EmailSettingsView> {
    const patch = splitPatch('EMAIL', body as unknown as Record<string, unknown>);
    validateEmailPatch(patch.config ?? {});
    if (await this.emailLoginEnabled()) {
      const next = effectiveEmailConfig(this.mail.envForSettings(), merge(await this.settings.values('EMAIL'), patch));
      if (!emailConfigured(next)) {
        throw integrationError(
          409,
          'EMAIL_LOGIN_NEEDS_PROVIDER',
          'Đăng nhập bằng email đang bật: cấu hình mới phải đủ để gửi email',
        );
      }
    }
    await this.settings.update('EMAIL', patch, actorUserId, body.reason);
    return this.emailView();
  }

  async testEmail(to: string, reason: string, actorUserId: string): Promise<{ ok: boolean; error: string | null; view: EmailSettingsView }> {
    const email = to.trim();
    if (!isEmailAddress(email)) {
      throw integrationError(400, 'VALIDATION_ERROR', 'Email nhận không hợp lệ');
    }
    const status = await this.mail.status();
    let error: string | null = null;
    if (!status.configured) {
      error = 'not_configured';
    } else {
      try {
        await this.mailSender.sendTestEmail({ email });
      } catch (caught) {
        error = caught instanceof MailDeliveryError ? caught.reason : 'provider_unavailable';
      }
    }
    await this.settings.recordTest(
      'EMAIL',
      { ok: error === null, fingerprint: status.fingerprint, detail: `${status.provider}: ${error ?? 'sent'}` },
      actorUserId,
      reason,
    );
    return { ok: error === null, error, view: await this.emailView() };
  }

  private async emailLoginEnabled(): Promise<boolean> {
    return Boolean((await this.authMethods.findByMethod('EMAIL_LOGIN_IDENTIFIER'))?.enabled);
  }

  // ── Map keys ─────────────────────────────────────────────────────────────

  async mapKeysView(): Promise<MapKeysView> {
    const values = await this.settings.values('MAPS');
    const keys = await this.mapKeys.effective();
    return {
      canStoreSecrets: this.settings.canStoreSecrets(),
      secretsUnreadable: values.secretsUnreadable,
      keys: INTEGRATION_FIELDS.MAPS.secrets.map((field) => ({
        field,
        set: Boolean(keys[field]),
        source: keys.sources[field],
        hint: keys[field] ? maskKey(keys[field]) : null,
      })),
      testedAt: values.testedAt?.toISOString() ?? null,
      updatedAt: values.updatedAt?.toISOString() ?? null,
    };
  }

  async updateMapKeys(body: PutMapKeysDto, actorUserId: string): Promise<MapKeysView> {
    const patch = splitPatch('MAPS', body as unknown as Record<string, unknown>);
    const publicToken = patch.secrets?.mapboxPublicToken?.trim();
    if (publicToken && !publicToken.startsWith('pk.')) {
      throw integrationError(400, 'VALIDATION_ERROR', 'Mapbox public token phải bắt đầu bằng pk.');
    }
    await this.settings.update('MAPS', patch, actorUserId, body.reason);
    return this.mapKeysView();
  }

  async testMapKeys(reason: string, actorUserId: string): Promise<{ results: MapKeyTestResult[]; view: MapKeysView }> {
    const keys = await this.mapKeys.effective();
    const results: MapKeyTestResult[] = [];
    for (const field of INTEGRATION_FIELDS.MAPS.secrets) {
      const key = keys[field];
      if (!key) {
        results.push({ field, ok: false, detail: 'unset' });
        continue;
      }
      results.push({ field, ...(field === 'googleMapsApiKey' ? await this.testGoogle(key) : await this.testMapbox(key)) });
    }
    const set = results.filter((r) => r.detail !== 'unset');
    const ok = set.length > 0 && set.every((r) => r.ok);
    await this.settings.recordTest(
      'MAPS',
      {
        ok,
        fingerprint: this.settings.fingerprint(INTEGRATION_FIELDS.MAPS.secrets.map((f) => keys[f])),
        detail: results.map((r) => `${r.field}=${r.ok ? 'ok' : r.detail}`).join(' '),
      },
      actorUserId,
      reason,
    );
    return { results, view: await this.mapKeysView() };
  }

  /** Public client config for app/web at runtime (no secrets: only the pk.* Mapbox token). */
  async clientConfig(): Promise<{ mapboxPublicToken: string | null }> {
    const keys = await this.mapKeys.effective();
    return { mapboxPublicToken: keys.mapboxPublicToken || null };
  }

  /** Mapbox token check (free endpoint, no map load billed). */
  private async testMapbox(token: string): Promise<{ ok: boolean; detail: string }> {
    try {
      const res = await this.fetcher(
        `https://api.mapbox.com/tokens/v2?access_token=${encodeURIComponent(token)}`,
        { signal: AbortSignal.timeout(KEY_TEST_TIMEOUT_MS) },
      );
      const body = (await res.json().catch(() => ({}))) as { code?: string };
      return body.code === 'TokenValid' ? { ok: true, detail: 'TokenValid' } : { ok: false, detail: body.code ?? `HTTP ${res.status}` };
    } catch (error) {
      return { ok: false, detail: (error as Error).name === 'TimeoutError' ? 'timeout' : 'network_error' };
    }
  }

  /** Google key check via one Geocoding request (Places/Routes must be enabled on the same key too). */
  private async testGoogle(key: string): Promise<{ ok: boolean; detail: string }> {
    try {
      const res = await this.fetcher(
        `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent('Đà Nẵng')}&region=vn&key=${encodeURIComponent(key)}`,
        { signal: AbortSignal.timeout(KEY_TEST_TIMEOUT_MS) },
      );
      const body = (await res.json().catch(() => ({}))) as { status?: string };
      const status = body.status ?? `HTTP ${res.status}`;
      return { ok: status === 'OK' || status === 'ZERO_RESULTS', detail: status };
    } catch (error) {
      return { ok: false, detail: (error as Error).name === 'TimeoutError' ? 'timeout' : 'network_error' };
    }
  }
}

function splitPatch(kind: 'EMAIL' | 'MAPS', body: Record<string, unknown>): IntegrationPatch {
  const fields = INTEGRATION_FIELDS[kind];
  const config: Record<string, string | null> = {};
  const secrets: Record<string, string | null> = {};
  for (const [key, value] of Object.entries(body)) {
    if (key === 'reason' || value === undefined) continue;
    const normalized = typeof value === 'string' ? value : null;
    if ((fields.config as readonly string[]).includes(key)) config[key] = normalized;
    else if ((fields.secrets as readonly string[]).includes(key)) secrets[key] = normalized;
  }
  return { config, secrets };
}

function validateEmailPatch(config: Record<string, string | null | undefined>): void {
  const bad = (message: string) => integrationError(400, 'VALIDATION_ERROR', message);
  const v = (key: string) => config[key]?.trim();
  const provider = v('provider');
  if (provider && !(EMAIL_PROVIDER_CHOICES as readonly string[]).includes(provider)) {
    throw bad('provider phải là smtp, ses hoặc disabled');
  }
  const from = v('fromAddress');
  if (from && !isEmailAddress(from)) throw bad('Địa chỉ gửi không hợp lệ');
  const port = v('smtpPort');
  if (port && !(/^\d+$/.test(port) && Number(port) >= 1 && Number(port) <= 65535)) throw bad('Cổng SMTP không hợp lệ');
  const secure = v('smtpSecure');
  if (secure && secure !== 'true' && secure !== 'false') throw bad('smtpSecure phải là true hoặc false');
  const host = v('smtpHost');
  if (host && !/^[A-Za-z0-9.-]+$/.test(host)) throw bad('SMTP host không hợp lệ');
  const region = v('sesRegion');
  if (region && !SES_REGION.test(region)) throw bad('SES region không hợp lệ');
  const arn = v('sesSnsTopicArn');
  if (arn && !SNS_TOPIC_ARN.test(arn)) throw bad('SNS topic ARN không hợp lệ');
}

function merge(current: IntegrationValues, patch: IntegrationPatch): Pick<IntegrationValues, 'config' | 'secrets'> {
  const apply = (base: Record<string, string>, changes: Record<string, string | null | undefined> = {}) => {
    const out = { ...base };
    for (const [key, raw] of Object.entries(changes)) {
      if (raw === undefined) continue;
      const value = (raw ?? '').trim();
      if (value) out[key] = value;
      else delete out[key];
    }
    return out;
  };
  return { config: apply(current.config, patch.config), secrets: apply(current.secrets, patch.secrets) };
}

/** Last 4 characters only, so admins can tell keys apart without exposing them. */
function maskKey(key: string): string {
  return key.length > 8 ? `…${key.slice(-4)}` : '…';
}
