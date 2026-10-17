import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import {
  PLATFORM_SETTING_SPECS,
  isPlatformSettingKey,
  specForKey,
  type PlatformSettingKey,
  type PlatformSettingValueTypeName,
} from './platform-settings.catalog.js';
import {
  PLATFORM_SETTINGS_CACHE_TTL_MS,
  PLATFORM_SETTINGS_REPOSITORY,
} from './platform-settings.constants.js';
import { settingsError } from './platform-settings.error.js';
import type {
  PlatformSettingRecord,
  PlatformSettingsRepository,
} from './platform-settings.repository.js';

export type PlatformSettingView = {
  key: PlatformSettingKey;
  value: string;
  valueType: PlatformSettingValueTypeName;
  source: 'db' | 'env';
  openIds: readonly string[];
  updatedAt: string | null;
  updatedByUserId: string | null;
};

function categorizeSettingKey(key: string): 'FARE' | 'DISPATCH' | 'ZONE_PAYMENT' {
  if (
    key.startsWith('RIDE_MIN') ||
    key.startsWith('RIDE_MAX') ||
    key.startsWith('RIDE_REF') ||
    key.startsWith('FOOD_MIN') ||
    key.startsWith('FOOD_MAX') ||
    key.startsWith('FOOD_DELIVERY')
  ) {
    return 'FARE';
  }
  if (
    key.includes('RADIUS') ||
    key.includes('TTL') ||
    key.includes('ROUNDS') ||
    key.includes('JOBS') ||
    key.includes('WINDOW')
  ) {
    return 'DISPATCH';
  }
  return 'ZONE_PAYMENT';
}

@Injectable()
export class PlatformSettingsService {
  private cache: { at: number; byKey: Map<PlatformSettingKey, PlatformSettingRecord> } | null =
    null;
  private seeded = false;

  constructor(
    @Inject(PLATFORM_SETTINGS_REPOSITORY) private readonly repo: PlatformSettingsRepository,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  async list(query?: {
    q?: string;
    category?: string;
    source?: string;
  }): Promise<PlatformSettingView[]> {
    await this.ensureSeeded();
    const rows = await this.repo.list();
    const byKey = new Map(rows.map((r) => [r.key, r]));
    this.cache = { at: Date.now(), byKey };
    let views = PLATFORM_SETTING_SPECS.map((spec) => {
      const row = byKey.get(spec.key);
      if (row) {
        return toView(row, 'db', spec.openIds);
      }
      return {
        key: spec.key,
        value: this.envDefaultString(spec.key),
        valueType: spec.valueType,
        source: 'env' as const,
        openIds: spec.openIds,
        updatedAt: null,
        updatedByUserId: null,
      };
    });

    if (query?.source && query.source !== 'ALL') {
      views = views.filter((v) => v.source === query.source);
    }
    if (query?.category && query.category !== 'ALL') {
      views = views.filter((v) => categorizeSettingKey(v.key) === query.category);
    }
    if (query?.q && query.q.trim()) {
      const q = query.q.trim().toLowerCase();
      views = views.filter(
        (v) =>
          v.key.toLowerCase().includes(q) ||
          v.value.toLowerCase().includes(q) ||
          v.openIds.some((id) => id.toLowerCase().includes(q)),
      );
    }

    return views;
  }

  async patch(
    keyRaw: string,
    value: string,
    reason: string,
    actorUserId: string,
  ): Promise<PlatformSettingView> {
    if (!isPlatformSettingKey(keyRaw)) {
      throw settingsError(404, 'PLATFORM_SETTING_UNKNOWN', `Unknown setting key: ${keyRaw}`);
    }
    const key = keyRaw;
    const spec = specForKey(key);
    const normalized = this.validateAndNormalize(key, value);
    await this.ensureSeeded();
    await this.assertCrossKeyInvariants(key, normalized);
    const previous = await this.repo.findByKey(key);
    const updated = await this.repo.upsert({
      key,
      value: normalized,
      valueType: spec.valueType,
      updatedByUserId: actorUserId,
      reason,
      previousValue: previous?.value ?? this.envDefaultString(key),
    });
    this.invalidateCache();
    return toView(updated, 'db', spec.openIds);
  }

  async getNumber(key: PlatformSettingKey): Promise<number> {
    const raw = await this.resolveRaw(key);
    if (raw === null || raw === '') {
      throw settingsError(500, 'PLATFORM_SETTING_MISSING', `Missing required setting ${key}`);
    }
    const n = Number(raw);
    if (!Number.isFinite(n)) {
      throw settingsError(500, 'PLATFORM_SETTING_INVALID', `Setting ${key} is not a number`);
    }
    return n;
  }

  async getOptionalNumber(key: PlatformSettingKey): Promise<number | undefined> {
    const raw = await this.resolveRaw(key);
    if (raw === null || raw === undefined || raw === '') {
      return undefined;
    }
    const n = Number(raw);
    if (!Number.isFinite(n)) {
      throw settingsError(500, 'PLATFORM_SETTING_INVALID', `Setting ${key} is not a number`);
    }
    return n;
  }

  async getString(key: PlatformSettingKey): Promise<string> {
    const raw = await this.resolveRaw(key);
    if (raw === null) {
      return this.envDefaultString(key);
    }
    return raw;
  }

  async getJson<T = unknown>(key: PlatformSettingKey): Promise<T> {
    const raw = await this.resolveRaw(key);
    const source = raw ?? this.envDefaultString(key);
    try {
      return JSON.parse(source) as T;
    } catch {
      throw settingsError(500, 'PLATFORM_SETTING_INVALID', `Setting ${key} is not valid JSON`);
    }
  }

  invalidateCache(): void {
    this.cache = null;
  }

  private async resolveRaw(key: PlatformSettingKey): Promise<string | null> {
    await this.ensureSeeded();
    const cached = this.readCache(key);
    if (cached !== undefined) {
      return cached?.value ?? null;
    }
    const row = await this.repo.findByKey(key);
    this.writeCacheEntry(key, row);
    if (row) {
      return row.value;
    }
    return this.envDefaultString(key);
  }

  private readCache(key: PlatformSettingKey): PlatformSettingRecord | null | undefined {
    if (!this.cache) {
      return undefined;
    }
    if (Date.now() - this.cache.at > PLATFORM_SETTINGS_CACHE_TTL_MS) {
      this.cache = null;
      return undefined;
    }
    return this.cache.byKey.has(key) ? (this.cache.byKey.get(key) ?? null) : undefined;
  }

  private writeCacheEntry(key: PlatformSettingKey, row: PlatformSettingRecord | null): void {
    if (!this.cache || Date.now() - this.cache.at > PLATFORM_SETTINGS_CACHE_TTL_MS) {
      this.cache = { at: Date.now(), byKey: new Map() };
    }
    if (row) {
      this.cache.byKey.set(key, row);
    }
  }

  private async ensureSeeded(): Promise<void> {
    if (this.seeded) {
      return;
    }
    const defaults = PLATFORM_SETTING_SPECS.map((spec) => ({
      key: spec.key,
      value: this.envDefaultString(spec.key),
      valueType: spec.valueType,
    })).filter((row) => row.value !== '');
    await this.repo.ensureDefaults(defaults);
    this.seeded = true;
  }

  private envDefaultString(key: PlatformSettingKey): string {
    switch (key) {
      case 'DRIVER_SEARCH_RADIUS_KM':
        return String(this.config.get('DRIVER_SEARCH_RADIUS_KM', { infer: true }));
      case 'RIDE_OFFER_TTL_SECONDS':
        return String(this.config.get('RIDE_OFFER_TTL_SECONDS', { infer: true }));
      case 'RIDE_NEGOTIATION_MAX_ROUNDS': {
        const v = this.config.get('RIDE_NEGOTIATION_MAX_ROUNDS', { infer: true });
        return v === undefined ? '' : String(v);
      }
      case 'RIDE_MIN_FARE_VND':
        return String(this.config.get('RIDE_MIN_FARE_VND', { infer: true }));
      case 'RIDE_MAX_FARE_VND':
        return String(this.config.get('RIDE_MAX_FARE_VND', { infer: true }));
      case 'RIDE_REFERENCE_VND_PER_KM':
        return String(this.config.get('RIDE_REFERENCE_VND_PER_KM', { infer: true }));
      case 'FOOD_MIN_DELIVERY_VND':
        return String(this.config.get('FOOD_MIN_DELIVERY_VND', { infer: true }));
      case 'FOOD_MAX_DELIVERY_VND':
        return String(this.config.get('FOOD_MAX_DELIVERY_VND', { infer: true }));
      case 'FOOD_DELIVERY_VND_PER_KM':
        return String(this.config.get('FOOD_DELIVERY_VND_PER_KM', { infer: true }));
      case 'CONTACT_WINDOW_MINUTES':
        return String(this.config.get('CONTACT_WINDOW_MINUTES', { infer: true }));
      case 'MAX_CONCURRENT_JOBS_PER_DRIVER':
        return String(this.config.get('MAX_CONCURRENT_JOBS_PER_DRIVER', { infer: true }));
      case 'PAYMENT_METHODS_ENABLED':
        return this.config.get('PAYMENT_METHODS_ENABLED', { infer: true });
      default: {
        const _exhaustive: never = key;
        return _exhaustive;
      }
    }
  }

  private validateAndNormalize(key: PlatformSettingKey, raw: string): string {
    const spec = specForKey(key);
    const trimmed = raw.trim();

    if (spec.valueType === 'string') {
      if (!trimmed && !spec.optional) {
        throw settingsError(400, 'PLATFORM_SETTING_INVALID', `${key} must be a non-empty string`);
      }
      if (trimmed.length > 200) {
        throw settingsError(400, 'PLATFORM_SETTING_INVALID', `${key} exceeds max length`);
      }
      return trimmed;
    }

    if (spec.valueType === 'json') {
      let parsed: unknown;
      try {
        parsed = JSON.parse(trimmed);
      } catch {
        throw settingsError(400, 'PLATFORM_SETTING_INVALID', `${key} must be valid JSON`);
      }
      if (key === 'PAYMENT_METHODS_ENABLED') {
        if (!Array.isArray(parsed) || !parsed.every((x) => typeof x === 'string' && x.length > 0)) {
          throw settingsError(
            400,
            'PLATFORM_SETTING_INVALID',
            'PAYMENT_METHODS_ENABLED must be a JSON array of non-empty strings',
          );
        }
      }
      return JSON.stringify(parsed);
    }

    if (trimmed === '' && spec.optional) {
      return '';
    }
    const n = Number(trimmed);
    if (!Number.isFinite(n)) {
      throw settingsError(400, 'PLATFORM_SETTING_INVALID', `${key} must be a number`);
    }
    if (spec.min !== undefined && n < spec.min) {
      throw settingsError(400, 'PLATFORM_SETTING_INVALID', `${key} must be >= ${spec.min}`);
    }
    if (spec.max !== undefined && n > spec.max) {
      throw settingsError(400, 'PLATFORM_SETTING_INVALID', `${key} must be <= ${spec.max}`);
    }
    if (
      key !== 'DRIVER_SEARCH_RADIUS_KM' &&
      !Number.isInteger(n)
    ) {
      throw settingsError(400, 'PLATFORM_SETTING_INVALID', `${key} must be an integer`);
    }
    return String(n);
  }

  private async assertCrossKeyInvariants(
    patchedKey: PlatformSettingKey,
    patchedValue: string,
  ): Promise<void> {
    const resolve = async (key: PlatformSettingKey): Promise<number> => {
      if (key === patchedKey) {
        return Number(patchedValue);
      }
      return this.getNumber(key);
    };
    if (patchedKey === 'RIDE_MIN_FARE_VND' || patchedKey === 'RIDE_MAX_FARE_VND') {
      const rideMin = await resolve('RIDE_MIN_FARE_VND');
      const rideMax = await resolve('RIDE_MAX_FARE_VND');
      if (rideMin > rideMax) {
        throw settingsError(
          400,
          'PLATFORM_SETTING_INVALID',
          'RIDE_MIN_FARE_VND must not exceed RIDE_MAX_FARE_VND',
        );
      }
    }
    if (patchedKey === 'FOOD_MIN_DELIVERY_VND' || patchedKey === 'FOOD_MAX_DELIVERY_VND') {
      const foodMin = await resolve('FOOD_MIN_DELIVERY_VND');
      const foodMax = await resolve('FOOD_MAX_DELIVERY_VND');
      if (foodMin > foodMax) {
        throw settingsError(
          400,
          'PLATFORM_SETTING_INVALID',
          'FOOD_MIN_DELIVERY_VND must not exceed FOOD_MAX_DELIVERY_VND',
        );
      }
    }
  }
}

function toView(
  row: PlatformSettingRecord,
  source: 'db' | 'env',
  openIds: readonly string[],
): PlatformSettingView {
  return {
    key: row.key,
    value: row.value,
    valueType: row.valueType,
    source,
    openIds,
    updatedAt: row.updatedAt.toISOString(),
    updatedByUserId: row.updatedByUserId,
  };
}
