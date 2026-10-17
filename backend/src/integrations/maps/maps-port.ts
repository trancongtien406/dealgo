import { Injectable, Logger } from '@nestjs/common';
import { haversineKm } from '../../shared/geo/haversine.js';
import { MOCK_DANANG_CENTER, MOCK_DANANG_LANDMARKS } from './maps.constants.js';

export type GeoPoint = { lat: number; lng: number };

export type GeocodeResult = {
  lat: number;
  lng: number;
  label: string;
  provider: 'mock' | 'goong' | 'google';
};

export interface MapsPort {
  geocode(query: string): Promise<GeocodeResult>;
  routeDistanceKm(origin: GeoPoint, destination: GeoPoint): Promise<number>;
}

export class UnavailableMapsError extends Error {
  constructor(message = 'Maps provider is not configured') {
    super(message);
    this.name = 'UnavailableMapsError';
  }
}

@Injectable()
export class MockMapsPort implements MapsPort {
  async geocode(query: string): Promise<GeocodeResult> {
    const normalized = query.trim().toLowerCase();
    for (const landmark of MOCK_DANANG_LANDMARKS) {
      if (landmark.keywords.some((keyword) => normalized.includes(keyword))) {
        return {
          lat: landmark.lat,
          lng: landmark.lng,
          label: landmark.label,
          provider: 'mock',
        };
      }
    }
    return {
      lat: MOCK_DANANG_CENTER.lat,
      lng: MOCK_DANANG_CENTER.lng,
      label: 'Da Nang (mock)',
      provider: 'mock',
    };
  }

  async routeDistanceKm(origin: GeoPoint, destination: GeoPoint): Promise<number> {
    return haversineKm(origin, destination);
  }
}

@Injectable()
export class UnavailableMapsPort implements MapsPort {
  async geocode(_query: string): Promise<GeocodeResult> {
    throw new UnavailableMapsError();
  }

  async routeDistanceKm(_origin: GeoPoint, _destination: GeoPoint): Promise<number> {
    throw new UnavailableMapsError();
  }
}

/**
 * Goong Directions Distance Matrix stub. Requires GOONG_API_KEY.
 * Network/API failures surface as UnavailableMapsError so callers may fall back.
 */
@Injectable()
export class GoongMapsPort implements MapsPort {
  private readonly logger = new Logger(GoongMapsPort.name);

  constructor(private readonly apiKey: string) {}

  async geocode(query: string): Promise<GeocodeResult> {
    const url = new URL('https://rsapi.goong.io/geocode');
    url.searchParams.set('address', query);
    url.searchParams.set('api_key', this.apiKey);
    const body = await this.fetchJson(url);
    const first = body?.results?.[0];
    const location = first?.geometry?.location;
    if (
      typeof location?.lat !== 'number' ||
      typeof location?.lng !== 'number' ||
      typeof first?.formatted_address !== 'string'
    ) {
      throw new UnavailableMapsError('Goong geocode returned no result');
    }
    return {
      lat: location.lat,
      lng: location.lng,
      label: first.formatted_address,
      provider: 'goong',
    };
  }

  async routeDistanceKm(origin: GeoPoint, destination: GeoPoint): Promise<number> {
    const url = new URL('https://rsapi.goong.io/DistanceMatrix');
    url.searchParams.set('origins', `${origin.lat},${origin.lng}`);
    url.searchParams.set('destinations', `${destination.lat},${destination.lng}`);
    url.searchParams.set('vehicle', 'bike');
    url.searchParams.set('api_key', this.apiKey);
    const body = await this.fetchJson(url);
    const meters = body?.rows?.[0]?.elements?.[0]?.distance?.value;
    if (typeof meters !== 'number' || !Number.isFinite(meters) || meters < 0) {
      throw new UnavailableMapsError('Goong distance matrix returned no distance');
    }
    return meters / 1000;
  }

  private async fetchJson(url: URL): Promise<MapsProviderJson> {
    try {
      const response = await fetch(url, {
        method: 'GET',
        signal: AbortSignal.timeout(5_000),
      });
      if (!response.ok) {
        this.logger.warn(`Goong HTTP ${response.status}`);
        throw new UnavailableMapsError(`Goong HTTP ${response.status}`);
      }
      return (await response.json()) as MapsProviderJson;
    } catch (error) {
      if (error instanceof UnavailableMapsError) {
        throw error;
      }
      this.logger.warn(`Goong request failed: ${error instanceof Error ? error.message : 'unknown'}`);
      throw new UnavailableMapsError('Goong request failed');
    }
  }
}

/**
 * Google Geocoding + Distance Matrix stub. Requires GOOGLE_MAPS_API_KEY.
 */
@Injectable()
export class GoogleMapsPort implements MapsPort {
  private readonly logger = new Logger(GoogleMapsPort.name);

  constructor(private readonly apiKey: string) {}

  async geocode(query: string): Promise<GeocodeResult> {
    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.searchParams.set('address', query);
    url.searchParams.set('key', this.apiKey);
    const body = await this.fetchJson(url);
    const first = body?.results?.[0];
    const location = first?.geometry?.location;
    if (
      typeof location?.lat !== 'number' ||
      typeof location?.lng !== 'number' ||
      typeof first?.formatted_address !== 'string'
    ) {
      throw new UnavailableMapsError('Google geocode returned no result');
    }
    return {
      lat: location.lat,
      lng: location.lng,
      label: first.formatted_address,
      provider: 'google',
    };
  }

  async routeDistanceKm(origin: GeoPoint, destination: GeoPoint): Promise<number> {
    const url = new URL('https://maps.googleapis.com/maps/api/distancematrix/json');
    url.searchParams.set('origins', `${origin.lat},${origin.lng}`);
    url.searchParams.set('destinations', `${destination.lat},${destination.lng}`);
    url.searchParams.set('mode', 'driving');
    url.searchParams.set('key', this.apiKey);
    const body = await this.fetchJson(url);
    const meters = body?.rows?.[0]?.elements?.[0]?.distance?.value;
    if (typeof meters !== 'number' || !Number.isFinite(meters) || meters < 0) {
      throw new UnavailableMapsError('Google distance matrix returned no distance');
    }
    return meters / 1000;
  }

  private async fetchJson(url: URL): Promise<MapsProviderJson> {
    try {
      const response = await fetch(url, {
        method: 'GET',
        signal: AbortSignal.timeout(5_000),
      });
      if (!response.ok) {
        this.logger.warn(`Google Maps HTTP ${response.status}`);
        throw new UnavailableMapsError(`Google Maps HTTP ${response.status}`);
      }
      return (await response.json()) as MapsProviderJson;
    } catch (error) {
      if (error instanceof UnavailableMapsError) {
        throw error;
      }
      this.logger.warn(
        `Google Maps request failed: ${error instanceof Error ? error.message : 'unknown'}`,
      );
      throw new UnavailableMapsError('Google Maps request failed');
    }
  }
}

type MapsProviderJson = {
  results?: Array<{
    formatted_address?: string;
    geometry?: { location?: { lat?: number; lng?: number } };
  }>;
  rows?: Array<{
    elements?: Array<{ distance?: { value?: number } }>;
  }>;
};

/** Prefer MapsPort distance; fall back to haversine when provider is unavailable. */
export async function resolveRouteDistanceKm(
  maps: MapsPort,
  origin: GeoPoint,
  destination: GeoPoint,
): Promise<number> {
  try {
    return await maps.routeDistanceKm(origin, destination);
  } catch (error) {
    if (error instanceof UnavailableMapsError) {
      return haversineKm(origin, destination);
    }
    throw error;
  }
}
