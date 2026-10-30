import type { PlatformSettingKey } from '../../src/platform/settings/platform-settings.catalog.js';
import { MemoryPlatformSettingsRepository } from '../../src/platform/settings/platform-settings.repository.js';

/** A memory settings repo with some keys pinned (everything else keeps its catalog default). */
export async function settingsWith(
  values: Partial<Record<PlatformSettingKey, number | string | boolean>>,
): Promise<MemoryPlatformSettingsRepository> {
  const repo = new MemoryPlatformSettingsRepository();
  for (const [key, value] of Object.entries(values)) {
    await repo.upsert({
      key: key as PlatformSettingKey,
      value: String(value),
      valueType: typeof value === 'number' ? 'number' : typeof value === 'boolean' ? 'json' : 'string',
      updatedByUserId: null,
      reason: 'test fixture',
      previousValue: null,
    });
  }
  return repo;
}

/**
 * Suites that exercise negotiation mechanics with small round fares (30 000 VND for a
 * ~9 km trip) switch the bid floor off; the floor has its own tests.
 */
export function negotiationMechanicsSettings(): Promise<MemoryPlatformSettingsRepository> {
  // Existing suites cover the pickup-code flow; the shipped default is off.
  return settingsWith({
    RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE: 0,
    RIDE_BID_CEILING_PERCENT_OF_REFERENCE: 0,
    RIDE_PICKUP_CODE_REQUIRED: true,
  });
}

/** Fixed small fares on short trips: bid floor and ceiling both off. */
export function bidBandOffSettings(): Promise<MemoryPlatformSettingsRepository> {
  return settingsWith({
    RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE: 0,
    RIDE_BID_CEILING_PERCENT_OF_REFERENCE: 0,
  });
}
