import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import type { MapsSecretField } from './integration-settings.constants.js';
import { IntegrationSettingsService } from './integration-settings.service.js';

export type MapKeySource = 'admin' | 'env' | 'unset';

export type EffectiveMapKeys = {
  /** Mapbox public token (pk.*): map tiles in app/web, served by GET /v1/public/client-config. */
  mapboxPublicToken: string;
  /** Mapbox server token: Directions (routing) and server geocoding fallback. Never sent to clients. */
  mapboxServerToken: string;
  /** Google Maps Platform key (Places, Geocoding, Routes) for capabilities Admin switches to Google. */
  googleMapsApiKey: string;
  sources: Record<MapsSecretField, MapKeySource>;
};

type MapKeysEnv = Pick<AppEnv, 'MAPBOX_ACCESS_TOKEN' | 'MAPBOX_DIRECTIONS_TOKEN' | 'GOOGLE_MAPS_API_KEY'>;

export function effectiveMapKeys(env: Partial<MapKeysEnv>, admin: Record<string, string>): EffectiveMapKeys {
  const envDefaults: Record<MapsSecretField, string> = {
    mapboxPublicToken: (env.MAPBOX_ACCESS_TOKEN ?? '').trim().startsWith('pk.') ? env.MAPBOX_ACCESS_TOKEN!.trim() : '',
    mapboxServerToken: (env.MAPBOX_DIRECTIONS_TOKEN ?? '').trim(),
    googleMapsApiKey: (env.GOOGLE_MAPS_API_KEY ?? '').trim(),
  };
  const sources = {} as EffectiveMapKeys['sources'];
  const pick = (field: MapsSecretField): string => {
    if (admin[field]) {
      sources[field] = 'admin';
      return admin[field]!;
    }
    sources[field] = envDefaults[field] ? 'env' : 'unset';
    return envDefaults[field];
  };
  return {
    mapboxPublicToken: pick('mapboxPublicToken'),
    mapboxServerToken: pick('mapboxServerToken'),
    googleMapsApiKey: pick('googleMapsApiKey'),
    sources,
  };
}

/**
 * Map keys from Admin › Cài đặt › Bản đồ (encrypted in DB) over env. Server code reads them per call
 * (cache ≤ INTEGRATION_SETTINGS_CACHE_TTL_MS); `snapshot()` serves sync callers with the last value.
 */
@Injectable()
export class MapKeysService {
  private readonly logger = new Logger(MapKeysService.name);
  private readonly env: MapKeysEnv;
  private last: EffectiveMapKeys;

  constructor(
    private readonly settings: IntegrationSettingsService,
    config: ConfigService<AppEnv, true>,
  ) {
    this.env = {
      MAPBOX_ACCESS_TOKEN: config.get('MAPBOX_ACCESS_TOKEN', { infer: true }),
      MAPBOX_DIRECTIONS_TOKEN: config.get('MAPBOX_DIRECTIONS_TOKEN', { infer: true }),
      GOOGLE_MAPS_API_KEY: config.get('GOOGLE_MAPS_API_KEY', { infer: true }),
    };
    this.last = effectiveMapKeys(this.env, {});
  }

  async effective(): Promise<EffectiveMapKeys> {
    const values = await this.settings.values('MAPS');
    this.last = effectiveMapKeys(this.env, values.secrets);
    return this.last;
  }

  /** Last resolved keys without awaiting (refreshes in the background). */
  snapshot(): EffectiveMapKeys {
    void this.effective().catch((error: Error) => this.logger.warn(`Map keys refresh failed: ${error.message}`));
    return this.last;
  }
}
