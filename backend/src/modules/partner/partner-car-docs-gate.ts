import type { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import type { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { isCarVehicleClassCode, vehicleClassCodeFromMetadata } from '../ride-vehicle/ride-vehicle-class.js';
import { PARTNER_DRIVER_CAR_EXTRA_DOCUMENTS } from './partner.constants.js';

/**
 * t90u: one answer to "must a car driver have VEHICLE_INSURANCE?".
 * Admin setting DRIVER_CAR_EXTRA_DOCS_REQUIRED decides (seed default true, cached by the
 * settings service). Without the settings service (unit wiring) the legacy env
 * PARTNER_CAR_KYC_EXTRA_DOCS applies, defaulting on in production. A settings read error
 * fails closed (gate on).
 */
export async function resolveCarExtraDocsGate(
  settings: PlatformSettingsService | undefined | null,
  config: ConfigService<AppEnv, true> | undefined | null,
): Promise<boolean> {
  if (settings) {
    try {
      return await settings.getBoolean('DRIVER_CAR_EXTRA_DOCS_REQUIRED');
    } catch {
      return true;
    }
  }
  if (!config) {
    return false;
  }
  const explicit = config.get('PARTNER_CAR_KYC_EXTRA_DOCS', { infer: true });
  if (explicit !== undefined) {
    return explicit;
  }
  return config.get('NODE_ENV', { infer: true }) === 'production';
}

/** Car extra documents missing from an application (empty for motorbike / unknown class). */
export function missingCarExtraDocs(
  metadata: Record<string, unknown> | null | undefined,
  documents: ReadonlyArray<{ kind?: string | null }> | null | undefined,
): string[] {
  const code = vehicleClassCodeFromMetadata(metadata ?? undefined);
  if (!code || !isCarVehicleClassCode(code)) {
    return [];
  }
  const onFile = new Set(
    (documents ?? [])
      .map((doc) => doc.kind)
      .filter((kind): kind is string => typeof kind === 'string' && kind.length > 0),
  );
  return PARTNER_DRIVER_CAR_EXTRA_DOCUMENTS.filter((kind) => !onFile.has(kind));
}
