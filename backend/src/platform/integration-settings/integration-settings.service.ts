import { createHash, createHmac } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import {
  INTEGRATION_FIELDS,
  INTEGRATION_SETTINGS_CACHE_TTL_MS,
  INTEGRATION_SETTINGS_REPOSITORY,
  integrationError,
} from './integration-settings.constants.js';
import type {
  IntegrationKindName,
  IntegrationSettingRecord,
  IntegrationSettingsRepository,
} from './integration-settings.repository.js';
import { SecretBox, SecretBoxError } from './secret-box.js';

/** Admin overrides for one integration, secrets decrypted (server-side only). */
export type IntegrationValues = {
  config: Record<string, string>;
  secrets: Record<string, string>;
  testedFingerprint: string | null;
  testedAt: Date | null;
  updatedAt: Date | null;
  updatedByUserId: string | null;
  /** True when a stored envelope could not be decrypted (key changed); secrets fall back to env. */
  secretsUnreadable: boolean;
};

/** `null` or '' clears the Admin value (env default applies again); omitted keys are unchanged. */
export type IntegrationPatch = {
  config?: Record<string, string | null | undefined>;
  secrets?: Record<string, string | null | undefined>;
};

const EMPTY: IntegrationValues = {
  config: {},
  secrets: {},
  testedFingerprint: null,
  testedAt: null,
  updatedAt: null,
  updatedByUserId: null,
  secretsUnreadable: false,
};

@Injectable()
export class IntegrationSettingsService {
  private readonly logger = new Logger(IntegrationSettingsService.name);
  private readonly box: SecretBox | null;
  private readonly fingerprintKey: string;
  private readonly cache = new Map<IntegrationKindName, { at: number; value: IntegrationValues }>();

  constructor(
    @Inject(INTEGRATION_SETTINGS_REPOSITORY) private readonly repo: IntegrationSettingsRepository,
    config: ConfigService<AppEnv, true>,
  ) {
    const key = config.get('SECRETS_ENCRYPTION_KEY', { infer: true })?.trim();
    this.box = key ? new SecretBox(key) : null;
    this.fingerprintKey = key ?? '';
  }

  /** False when SECRETS_ENCRYPTION_KEY is unset: Admin cannot store credentials. */
  canStoreSecrets(): boolean {
    return this.box !== null;
  }

  async values(kind: IntegrationKindName): Promise<IntegrationValues> {
    const hit = this.cache.get(kind);
    if (hit && Date.now() - hit.at < INTEGRATION_SETTINGS_CACHE_TTL_MS) {
      return hit.value;
    }
    let value = EMPTY;
    try {
      const row = await this.repo.find(kind);
      value = row ? this.decode(row) : EMPTY;
    } catch (error) {
      // A DB hiccup must not take email/maps down: env defaults keep working.
      this.logger.warn(`Reading ${kind} integration settings failed: ${(error as Error).message}`);
      return hit?.value ?? EMPTY;
    }
    this.cache.set(kind, { at: Date.now(), value });
    return value;
  }

  async update(
    kind: IntegrationKindName,
    patch: IntegrationPatch,
    actorUserId: string,
    reason: string,
  ): Promise<IntegrationValues> {
    const fields = INTEGRATION_FIELDS[kind];
    const current = await this.fresh(kind);
    const config = { ...current.config };
    const secrets = { ...current.secrets };
    const changedConfig: Record<string, string | null> = {};
    const changedSecrets: Record<string, 'set' | 'cleared'> = {};

    for (const [key, raw] of Object.entries(patch.config ?? {})) {
      if (raw === undefined) continue;
      if (!(fields.config as readonly string[]).includes(key)) {
        throw integrationError(400, 'VALIDATION_ERROR', `Unknown ${kind} field: ${key}`);
      }
      const value = (raw ?? '').trim();
      if ((config[key] ?? '') === value) continue;
      if (value) config[key] = value;
      else delete config[key];
      changedConfig[key] = value || null;
    }
    for (const [key, raw] of Object.entries(patch.secrets ?? {})) {
      if (raw === undefined) continue;
      if (!(fields.secrets as readonly string[]).includes(key)) {
        throw integrationError(400, 'VALIDATION_ERROR', `Unknown ${kind} secret: ${key}`);
      }
      const value = (raw ?? '').trim();
      if ((secrets[key] ?? '') === value) continue;
      if (value) secrets[key] = value;
      else delete secrets[key];
      changedSecrets[key] = value ? 'set' : 'cleared';
    }
    if (Object.keys(changedConfig).length === 0 && Object.keys(changedSecrets).length === 0) {
      return current;
    }
    const hasSecrets = Object.keys(secrets).length > 0;
    if (hasSecrets && !this.box) {
      throw integrationError(
        409,
        'SECRETS_ENCRYPTION_KEY_MISSING',
        'Server chưa có SECRETS_ENCRYPTION_KEY nên không lưu được khoá/mật khẩu',
      );
    }
    await this.repo.write({
      kind,
      config,
      ...(Object.keys(changedSecrets).length > 0
        ? { secretsCiphertext: hasSecrets ? this.box!.seal(JSON.stringify(secrets), aad(kind)) : null }
        : {}),
      audit: {
        actorUserId,
        action: 'INTEGRATION_SETTING_UPDATE',
        reason,
        metadata: { config: changedConfig, secrets: changedSecrets },
      },
    });
    this.cache.delete(kind);
    return this.values(kind);
  }

  /** Stores the outcome of an Admin "test" (passing → fingerprint of the tested config). */
  async recordTest(
    kind: IntegrationKindName,
    input: { ok: boolean; fingerprint: string; detail: string },
    actorUserId: string,
    reason: string,
  ): Promise<void> {
    await this.repo.write({
      kind,
      testedFingerprint: input.ok ? input.fingerprint : null,
      testedAt: input.ok ? new Date() : null,
      audit: {
        actorUserId,
        action: 'INTEGRATION_SETTING_TEST',
        reason,
        metadata: { ok: input.ok, detail: input.detail.slice(0, 300) },
      },
    });
    this.cache.delete(kind);
  }

  /** Audits an action performed with an integration's stored credentials. */
  async recordAction(
    kind: IntegrationKindName,
    input: { action: 'SENTRY_ISSUE_STATUS_UPDATE'; metadata: Record<string, unknown> },
    actorUserId: string,
    reason: string,
  ): Promise<void> {
    await this.repo.audit(kind, { actorUserId, reason, ...input });
  }

  /** Keyed hash of an effective config (secrets included) so a later change invalidates a test. */
  fingerprint(parts: unknown): string {
    const json = JSON.stringify(parts);
    return this.fingerprintKey
      ? createHmac('sha256', this.fingerprintKey).update(json).digest('hex')
      : createHash('sha256').update(json).digest('hex');
  }

  private async fresh(kind: IntegrationKindName): Promise<IntegrationValues> {
    const row = await this.repo.find(kind);
    if (row) {
      const decoded = this.decode(row);
      if (decoded.secretsUnreadable) {
        throw integrationError(
          409,
          'SECRETS_UNREADABLE',
          'Không giải mã được khoá đã lưu (SECRETS_ENCRYPTION_KEY đã đổi?)',
        );
      }
      return decoded;
    }
    return EMPTY;
  }

  private decode(row: IntegrationSettingRecord): IntegrationValues {
    let secrets: Record<string, string> = {};
    let secretsUnreadable = false;
    if (row.secretsCiphertext) {
      try {
        if (!this.box) throw new SecretBoxError('SECRETS_ENCRYPTION_KEY is not set');
        const parsed = JSON.parse(this.box.open(row.secretsCiphertext, aad(row.kind))) as unknown;
        if (parsed && typeof parsed === 'object') {
          secrets = Object.fromEntries(
            Object.entries(parsed).filter((entry): entry is [string, string] => typeof entry[1] === 'string'),
          );
        }
      } catch (error) {
        secretsUnreadable = true;
        this.logger.error(`Stored ${row.kind} secrets unreadable: ${(error as Error).message}`);
      }
    }
    return {
      config: row.config,
      secrets,
      testedFingerprint: row.testedFingerprint,
      testedAt: row.testedAt,
      updatedAt: row.updatedAt,
      updatedByUserId: row.updatedByUserId,
      secretsUnreadable,
    };
  }
}

function aad(kind: IntegrationKindName): string {
  return `integration:${kind}`;
}
