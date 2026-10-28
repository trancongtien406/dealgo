import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { PlatformSettingsModule } from '../../platform/settings/platform-settings.module.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { GoogleMapsPort } from './google-maps.js';
import {
  MapsProviderSettings,
  SwitchingMapsPort,
} from './maps-provider-settings.js';
import { IntegrationSettingsModule } from '../../platform/integration-settings/integration-settings.module.js';
import { MapKeysService } from '../../platform/integration-settings/map-keys.service.js';
import {
  GoongMapsPort,
  KeyedMapsPort,
  MapboxMapsPort,
  MockMapsPort,
  UnavailableMapsPort,
  type MapsPort,
} from './maps-port.js';
import { MAPS_PORT, OSM_SEARCH_PORT } from './maps.constants.js';
import { PhotonSearchPort, type OsmSearchPort } from './osm-search.js';

/**
 * Env-selected base provider (MAPS_PROVIDER; Mapbox in production). Its key follows Admin ›
 * Cài đặt › Bản đồ (DB) over env, re-read per call.
 */
function primaryMapsPort(config: ConfigService<AppEnv, true>, keys: MapKeysService): MapsPort {
  const provider = config.get('MAPS_PROVIDER', { infer: true });
  const nodeEnv = config.get('NODE_ENV', { infer: true });
  if ((provider === 'mock' || provider === undefined) && nodeEnv !== 'production') {
    return new MockMapsPort();
  }
  if (provider === 'mapbox') {
    return new KeyedMapsPort(
      async () => {
        const k = await keys.effective();
        return k.mapboxPublicToken || k.mapboxServerToken;
      },
      (key) => new MapboxMapsPort(key),
    );
  }
  if (provider === 'goong') {
    const key = config.get('GOONG_API_KEY', { infer: true });
    return key ? new GoongMapsPort(key) : new UnavailableMapsPort();
  }
  if (provider === 'google') {
    return new KeyedMapsPort(async () => (await keys.effective()).googleMapsApiKey, (key) => new GoogleMapsPort(key));
  }
  // Production without an explicit mock/provider, or unknown provider → unavailable.
  return new UnavailableMapsPort();
}

/** One GoogleMapsPort per distinct key (keeps its place-details cache across calls). */
function googleResolver(keys: MapKeysService): () => Promise<GoogleMapsPort | null> {
  let cached: { key: string; port: GoogleMapsPort } | null = null;
  return async () => {
    const key = (await keys.effective()).googleMapsApiKey;
    if (!key) return null;
    if (cached?.key !== key) cached = { key, port: new GoogleMapsPort(key) };
    return cached.port;
  };
}

@Module({
  imports: [PlatformSettingsModule, IntegrationSettingsModule],
  providers: [
    {
      provide: MapsProviderSettings,
      inject: [PlatformSettingsService, MapKeysService],
      useFactory: (settings: PlatformSettingsService, keys: MapKeysService) =>
        new MapsProviderSettings(settings, googleResolver(keys)),
    },
    {
      provide: MAPS_PORT,
      inject: [ConfigService, MapsProviderSettings, MapKeysService],
      useFactory: (
        config: ConfigService<AppEnv, true>,
        selector: MapsProviderSettings,
        keys: MapKeysService,
      ): MapsPort => new SwitchingMapsPort(primaryMapsPort(config, keys), selector),
    },
    {
      provide: OSM_SEARCH_PORT,
      inject: [ConfigService],
      useFactory: (
        config: ConfigService<AppEnv, true>,
      ): OsmSearchPort | null => {
        const url = config
          .get('PLACES_OSM_SEARCH_URL', { infer: true })
          ?.trim();
        return url ? new PhotonSearchPort(url) : null;
      },
    },
  ],
  exports: [MAPS_PORT, OSM_SEARCH_PORT, MapsProviderSettings, IntegrationSettingsModule],
})
export class MapsModule {}
