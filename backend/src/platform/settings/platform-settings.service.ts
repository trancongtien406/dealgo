import { Inject, Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import { MapKeysService } from '../integration-settings/map-keys.service.js';
import {
  MAPS_PROVIDER_CHOICES,
  MAPS_PROVIDER_SETTING_KEYS,
  PLATFORM_SETTING_SPECS,
  UPLOAD_SNIFFABLE_TYPES,
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
import {
  normalizePaymentMethodRegistry,
  validatePaymentMethodRegistry,
} from './payment-method-registry.js';
import { PLATFORM_SETTING_SEED_DEFAULTS } from './platform-settings.seed.js';
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

const SETTING_CATEGORY_OVERRIDES: Readonly<Record<string, 'FARE' | 'DISPATCH' | 'ZONE_PAYMENT'>> = {
  RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE: 'FARE',
  RIDE_COUNTER_MAX_PERCENT_OF_OFFER: 'FARE',
  RIDE_CANCEL_FEE_BIKE_VND: 'FARE',
  RIDE_CANCEL_FEE_CAR_VND: 'FARE',
  RIDE_FREE_CANCEL_MINUTES: 'FARE',
  RIDE_MAX_OFFER_EDITS_PER_DRIVER: 'DISPATCH',
  RIDE_REQUEST_WINDOW_SECONDS: 'DISPATCH',
  FOOD_MAX_DELIVERY_KM: 'ZONE_PAYMENT',
  SERVICE_ZONE_ENFORCED: 'ZONE_PAYMENT',
  DRIVER_DEBT_LIMIT_VND: 'ZONE_PAYMENT',
  RIDE_MAX_LIVE_OFFERS_PER_RIDE: 'DISPATCH',
  RIDE_MAX_FARE_RAISES_PER_RIDE: 'DISPATCH',
  ROUTE_OFF_ROUTE_THRESHOLD_M: 'DISPATCH',
  ROUTE_REROUTE_MIN_INTERVAL_SECONDS: 'DISPATCH',
  CUSTOMER_CANCEL_LIMIT_COUNT: 'DISPATCH',
  CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS: 'DISPATCH',
  CUSTOMER_CANCEL_COOLDOWN_MINUTES: 'DISPATCH',
  DRIVER_CANCEL_RATE_WINDOW_DAYS: 'DISPATCH',
  DRIVER_CANCEL_RATE_WARN_PERCENT: 'DISPATCH',
  RIDE_REQUEST_PUSH_ENABLED: 'DISPATCH',
  NEW_JOB_CUSTOM_SOUND_ENABLED: 'DISPATCH',
  RIDE_REQUEST_PUSH_MAX_DRIVERS: 'DISPATCH',
  FOOD_FAIL_MIN_WAIT_MINUTES: 'DISPATCH',
  FOOD_MERCHANT_COMMISSION_PERCENT: 'FARE',
  FOOD_ORDER_CHANGE_RESPONSE_MINUTES: 'DISPATCH',
  RIDE_REPOST_RAISE_HINT_PERCENT: 'FARE',
  RIDE_COMMISSION_BIKE_PERCENT: 'FARE',
  RIDE_COMMISSION_CAR_PERCENT: 'FARE',
  FOOD_DRIVER_COMMISSION_PERCENT: 'FARE',
  MERCHANT_SETTLEMENT_CYCLE_DAYS: 'FARE',
  VOUCHER_SHARED_PLATFORM_PERCENT: 'FARE',
};

function categorizeSettingKey(key: string): 'FARE' | 'DISPATCH' | 'ZONE_PAYMENT' | 'SUPPORT' {
  const override = SETTING_CATEGORY_OVERRIDES[key];
  if (override) {
    return override;
  }
  if (key.includes('TIMEOUT') || key.includes('NO_SHOW') || key.includes('EARLY_ASSIGN') || key.includes('PRESENCE')) {
    return 'DISPATCH';
  }
  if (
    key.startsWith('SUPPORT_') ||
    key.startsWith('UPLOAD_') ||
    key.startsWith('ACCOUNT_') ||
    key.startsWith('AUTH_') ||
    key.startsWith('ONBOARDING_') ||
    key.startsWith('VOICE_') ||
    key.startsWith('MAPS_')
  ) {
    return 'SUPPORT';
  }
  if (key.startsWith('PLATFORM_FEE') || key === 'VOUCHER_SHARED_PLATFORM_PERCENT') {
    return 'FARE';
  }
  if (
    key === 'RATING_STORE_MIN_COUNT' ||
    key === 'RATING_WINDOW_DAYS' ||
    key === 'RIDE_PICKUP_CODE_MAX_ATTEMPTS' ||
    key.startsWith('FOOD_DELIVERY_CODE') ||
    key === 'FOOD_HANDOVER_CODE_REQUIRED'
  ) {
    return 'DISPATCH';
  }
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
    @Optional() private readonly mapKeys?: MapKeysService,
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
    if ((MAPS_PROVIDER_SETTING_KEYS as readonly string[]).includes(key) && normalized === 'google') {
      await this.assertGoogleKey();
    }
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

  /** JSON boolean settings (spec.boolean); anything but `true` reads as false. */
  async getBoolean(key: PlatformSettingKey): Promise<boolean> {
    return (await this.getJson<unknown>(key)) === true;
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
      value: spec.seeded
        ? (PLATFORM_SETTING_SEED_DEFAULTS[spec.key] ?? '')
        : this.envDefaultString(spec.key),
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
      case 'PAYMENT_METHOD_REGISTRY':
      case 'PAYMENT_WALLET_ENABLED':
      case 'RATING_WINDOW_DAYS':
      case 'RIDE_COMMISSION_BIKE_PERCENT':
      case 'RIDE_COMMISSION_CAR_PERCENT':
      case 'FOOD_DRIVER_COMMISSION_PERCENT':
      case 'MERCHANT_SETTLEMENT_CYCLE_DAYS':
      case 'VOUCHER_SHARED_PLATFORM_PERCENT':
      case 'RIDE_PICKUP_CODE_MAX_ATTEMPTS':
      case 'FOOD_DELIVERY_CODE_REQUIRED':
      case 'FOOD_DELIVERY_CODE_MAX_ATTEMPTS':
      case 'FOOD_HANDOVER_CODE_REQUIRED':
      case 'ONBOARDING_DRIVER_KYC_REQUIRED':
      case 'ONBOARDING_MERCHANT_KYB_REQUIRED':
      case 'SUPPORT_TICKET_MAX_OPEN_PER_USER':
      case 'SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY':
      case 'SUPPORT_TICKET_TEXT_MAX_CHARS':
      case 'RATING_STORE_MIN_COUNT':
      case 'UPLOAD_MAX_FILE_KB':
      case 'MENU_ITEM_MAX_IMAGES':
      case 'UPLOAD_ALLOWED_TYPES':
      case 'UPLOAD_ORPHAN_MAX_AGE_HOURS':
      case 'ACCOUNT_DELETION_GRACE_DAYS':
      case 'AUTH_PASSWORD_RESET_CODE_TTL_MINUTES':
      case 'AUTH_PASSWORD_RESET_MAX_ATTEMPTS':
      case 'AUTH_PASSWORD_RESET_MAX_PER_HOUR':
      case 'CHAT_RETENTION_DAYS':
      case 'APP_REVIEW_LOGIN_ENABLED':
      case 'APP_REVIEW_PHONE':
      case 'APP_REVIEW_EMAIL':
      case 'RIDE_REQUEST_WINDOW_SECONDS':
      case 'RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE':
      case 'RIDE_COUNTER_MAX_PERCENT_OF_OFFER':
      case 'RIDE_MAX_OFFER_EDITS_PER_DRIVER':
      case 'RIDE_ASSIGNED_START_TIMEOUT_MINUTES':
      case 'RIDE_EN_ROUTE_TIMEOUT_MINUTES':
      case 'RIDE_NO_SHOW_WAIT_MINUTES':
      case 'RIDE_FREE_CANCEL_MINUTES':
      case 'RIDE_CANCEL_FEE_BIKE_VND':
      case 'RIDE_CANCEL_FEE_CAR_VND':
      case 'FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES':
      case 'FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES':
      case 'FOOD_EARLY_ASSIGN_LEAD_MINUTES':
      case 'FOOD_MAX_DELIVERY_KM':
      case 'SERVICE_ZONE_ENFORCED':
      case 'DRIVER_DEBT_LIMIT_VND':
      case 'DISPATCH_REQUIRE_FRESH_PRESENCE':
      case 'RIDE_MAX_LIVE_OFFERS_PER_RIDE':
      case 'RIDE_MAX_FARE_RAISES_PER_RIDE':
      case 'ROUTE_OFF_ROUTE_THRESHOLD_M':
      case 'ROUTE_REROUTE_MIN_INTERVAL_SECONDS':
      case 'CUSTOMER_CANCEL_LIMIT_COUNT':
      case 'CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS':
      case 'CUSTOMER_CANCEL_COOLDOWN_MINUTES':
      case 'DRIVER_CANCEL_RATE_WINDOW_DAYS':
      case 'DRIVER_CANCEL_RATE_WARN_PERCENT':
      case 'RIDE_REQUEST_PUSH_ENABLED':
      case 'NEW_JOB_CUSTOM_SOUND_ENABLED':
      case 'VOICE_CALLS_ENABLED':
      case 'RIDE_REQUEST_PUSH_MAX_DRIVERS':
      case 'FOOD_FAIL_MIN_WAIT_MINUTES':
      case 'FOOD_MERCHANT_COMMISSION_PERCENT':
      case 'FOOD_ORDER_CHANGE_RESPONSE_MINUTES':
      case 'RIDE_REPOST_RAISE_HINT_PERCENT':
      case 'MAPS_SEARCH_PROVIDER':
      case 'MAPS_REVERSE_PROVIDER':
      case 'MAPS_ROUTE_PROVIDER':
        // Seeded by migration/seed (PLATFORM_SETTING_SEED_DEFAULTS); no env bootstrap.
        return PLATFORM_SETTING_SEED_DEFAULTS[key] ?? '';
      default: {
        const _exhaustive: never = key;
        return _exhaustive;
      }
    }
  }

  private normalizeMapsProvider(key: PlatformSettingKey, value: string): string {
    const choice = value.toLowerCase();
    if (!(MAPS_PROVIDER_CHOICES as readonly string[]).includes(choice)) {
      throw settingsError(400, 'PLATFORM_SETTING_INVALID', `${key} must be mapbox or google`);
    }
    return choice;
  }

  /** Google is selectable only with a key (Admin › Cài đặt › Bản đồ, else GOOGLE_MAPS_API_KEY). */
  private async assertGoogleKey(): Promise<void> {
    const key = this.mapKeys
      ? (await this.mapKeys.effective()).googleMapsApiKey
      : (this.config.get('GOOGLE_MAPS_API_KEY', { infer: true }) ?? '').trim();
    if (!key) {
      throw settingsError(400, 'MAPS_PROVIDER_NOT_CONFIGURED', 'Google Maps chưa có API key');
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
      if ((MAPS_PROVIDER_SETTING_KEYS as readonly string[]).includes(key)) {
        return this.normalizeMapsProvider(key, trimmed);
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
      if (spec.boolean && typeof parsed !== 'boolean') {
        throw settingsError(400, 'PLATFORM_SETTING_INVALID', `${key} must be true or false`);
      }
      if (key === 'PAYMENT_METHOD_REGISTRY') {
        const problem = validatePaymentMethodRegistry(parsed);
        if (problem) {
          throw settingsError(400, 'PLATFORM_SETTING_INVALID', problem);
        }
        return JSON.stringify(normalizePaymentMethodRegistry(parsed));
      }
      if (key === 'UPLOAD_ALLOWED_TYPES') {
        const allowed = UPLOAD_SNIFFABLE_TYPES as readonly string[];
        if (
          !Array.isArray(parsed) ||
          parsed.length === 0 ||
          !parsed.every((x) => typeof x === 'string' && allowed.includes(x)) ||
          new Set(parsed).size !== parsed.length
        ) {
          throw settingsError(
            400,
            'PLATFORM_SETTING_INVALID',
            `UPLOAD_ALLOWED_TYPES must be a non-empty JSON array of distinct values from ${allowed.join(', ')}`,
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
    if (spec.maxDecimals !== undefined) {
      const decimals = trimmed.includes('.') ? trimmed.split('.')[1].replace(/0+$/, '').length : 0;
      if (!/^-?\d+(\.\d+)?$/.test(trimmed) || decimals > spec.maxDecimals) {
        throw settingsError(
          400,
          'PLATFORM_SETTING_INVALID',
          `${key} allows at most ${spec.maxDecimals} decimal places`,
        );
      }
    } else if (key !== 'DRIVER_SEARCH_RADIUS_KM' && !Number.isInteger(n)) {
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
