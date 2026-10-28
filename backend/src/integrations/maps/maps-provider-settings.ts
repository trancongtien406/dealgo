import { Logger } from '@nestjs/common';
import type {
  MapsProviderChoice,
  PlatformSettingKey,
} from '../../platform/settings/platform-settings.catalog.js';
import type { GoogleMapsPort } from './google-maps.js';
import {
  UnavailableMapsError,
  type GeoPoint,
  type GeocodeResult,
  type MapsPort,
  type PlaceSuggestion,
} from './maps-port.js';

export type MapsCapability = 'search' | 'reverse' | 'route';

export const MAPS_CAPABILITY_SETTING: Record<MapsCapability, PlatformSettingKey> = {
  search: 'MAPS_SEARCH_PROVIDER',
  reverse: 'MAPS_REVERSE_PROVIDER',
  route: 'MAPS_ROUTE_PROVIDER',
};

/** The subset of PlatformSettingsService this selector reads (keeps specs light). */
export type MapsSettingsReader = { getString(key: PlatformSettingKey): Promise<string> };

/** A fixed Google port, none, or a resolver that follows the key in Admin › Bản đồ (DB over env). */
export type GoogleSource = GoogleMapsPort | null | (() => Promise<GoogleMapsPort | null>);

/**
 * Which provider serves each map capability. Admin picks per capability in platform settings;
 * Google is only effective when a Google key is set (Admin or GOOGLE_MAPS_API_KEY), otherwise everything stays on the
 * env-configured primary (Mapbox in production). A settings read failure also means Mapbox.
 */
export class MapsProviderSettings {
  private readonly logger = new Logger(MapsProviderSettings.name);

  constructor(
    private readonly settings: MapsSettingsReader,
    private readonly google: GoogleSource,
  ) {}

  async googlePort(): Promise<GoogleMapsPort | null> {
    if (typeof this.google !== 'function') return this.google;
    try {
      return await this.google();
    } catch (error) {
      this.logger.warn(`Resolving Google key failed: ${(error as Error).message}`);
      return null;
    }
  }

  async googleConfigured(): Promise<boolean> {
    return (await this.googlePort()) !== null;
  }

  /** The admin's stored choice (may be google even if the key was later removed). */
  async chosen(capability: MapsCapability): Promise<MapsProviderChoice> {
    try {
      const raw = (await this.settings.getString(MAPS_CAPABILITY_SETTING[capability])).trim().toLowerCase();
      return raw === 'google' ? 'google' : 'mapbox';
    } catch (error) {
      this.logger.warn(`Reading ${capability} map provider failed: ${(error as Error).message}`);
      return 'mapbox';
    }
  }

  /** The provider actually used right now. */
  async effective(capability: MapsCapability): Promise<MapsProviderChoice> {
    if (!(await this.googlePort())) return 'mapbox';
    return this.chosen(capability);
  }
}

/**
 * MAPS_PORT: delegates each call to Google or the primary port per the admin setting.
 * Google failures (quota, denied key, timeout) fall back to the primary so riders are never
 * stuck; forward geocode follows the search choice, route distance the route choice.
 */
export class SwitchingMapsPort implements MapsPort {
  private readonly logger = new Logger(SwitchingMapsPort.name);

  constructor(
    private readonly primary: MapsPort,
    private readonly selector: MapsProviderSettings,
  ) {}

  geocode(query: string): Promise<GeocodeResult> {
    return this.run('search', (p) => p.geocode(query));
  }

  searchPlaces(query: string, limit: number, near?: GeoPoint): Promise<PlaceSuggestion[]> {
    return this.run('search', (p) => p.searchPlaces(query, limit, near));
  }

  reverseGeocode(point: GeoPoint): Promise<PlaceSuggestion | null> {
    return this.run('reverse', (p) => p.reverseGeocode(point));
  }

  routeDistanceKm(origin: GeoPoint, destination: GeoPoint): Promise<number> {
    return this.run('route', (p) => p.routeDistanceKm(origin, destination));
  }

  private async run<T>(capability: MapsCapability, call: (port: MapsPort) => Promise<T>): Promise<T> {
    const google = await this.selector.googlePort();
    if (google && (await this.selector.effective(capability)) === 'google') {
      try {
        return await call(google);
      } catch (error) {
        if (!(error instanceof UnavailableMapsError)) throw error;
        this.logger.warn(`Google ${capability} unavailable, falling back to primary`);
      }
    }
    return call(this.primary);
  }
}
