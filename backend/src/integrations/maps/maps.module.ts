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
import {
  GoongMapsPort,
  MapboxMapsPort,
  MockMapsPort,
  UnavailableMapsPort,
  type MapsPort,
} from './maps-port.js';
import { MAPS_PORT, OSM_SEARCH_PORT } from './maps.constants.js';
import { PhotonSearchPort, type OsmSearchPort } from './osm-search.js';

/** Env-configured base port (Mapbox in production); admin can switch capabilities to Google. */
function primaryMapsPort(config: ConfigService<AppEnv, true>): MapsPort {
  const provider = config.get('MAPS_PROVIDER', { infer: true });
  const nodeEnv = config.get('NODE_ENV', { infer: true });
  if (
    (provider === 'mock' || provider === undefined) &&
    nodeEnv !== 'production'
  ) {
    return new MockMapsPort();
  }
  if (provider === 'mapbox') {
    const key =
      config.get('MAPBOX_ACCESS_TOKEN', { infer: true })?.trim() ||
      config.get('MAPBOX_DIRECTIONS_TOKEN', { infer: true })?.trim();
    if (!key) {
      return new UnavailableMapsPort();
    }
    return new MapboxMapsPort(key);
  }
  if (provider === 'goong') {
    const key = config.get('GOONG_API_KEY', { infer: true });
    if (!key) {
      return new UnavailableMapsPort();
    }
    return new GoongMapsPort(key);
  }
  if (provider === 'google') {
    const key = config.get('GOOGLE_MAPS_API_KEY', { infer: true })?.trim();
    return key ? new GoogleMapsPort(key) : new UnavailableMapsPort();
  }
  // Production without an explicit mock/provider, or unknown provider → unavailable.
  return new UnavailableMapsPort();
}

@Module({
  imports: [PlatformSettingsModule],
  providers: [
    {
      provide: MapsProviderSettings,
      inject: [ConfigService, PlatformSettingsService],
      useFactory: (
        config: ConfigService<AppEnv, true>,
        settings: PlatformSettingsService,
      ) => {
        const key = config.get('GOOGLE_MAPS_API_KEY', { infer: true })?.trim();
        return new MapsProviderSettings(
          settings,
          key ? new GoogleMapsPort(key) : null,
        );
      },
    },
    {
      provide: MAPS_PORT,
      inject: [ConfigService, MapsProviderSettings],
      useFactory: (
        config: ConfigService<AppEnv, true>,
        selector: MapsProviderSettings,
      ): MapsPort => new SwitchingMapsPort(primaryMapsPort(config), selector),
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
  exports: [MAPS_PORT, OSM_SEARCH_PORT, MapsProviderSettings],
})
export class MapsModule {}
