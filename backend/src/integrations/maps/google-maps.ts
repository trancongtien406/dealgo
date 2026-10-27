import { Logger } from '@nestjs/common';
import {
  UnavailableMapsError,
  type GeoPoint,
  type GeocodeResult,
  type MapsPort,
  type PlaceKind,
  type PlaceSuggestion,
} from './maps-port.js';

/** Minimal fetch shape so specs can inject a fake transport. */
export type GoogleFetch = (
  url: string,
  init: { method: 'GET' | 'POST'; headers: Record<string, string>; body?: string; signal?: AbortSignal },
) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>;

/** One drivable route from the Routes API, in the shape RoutingService returns. */
export type GoogleRoute = {
  /** [lat, lng] pairs. */
  coords: [number, number][];
  distanceM: number;
  durationSec: number;
  summary: string;
};

const AUTOCOMPLETE_URL = 'https://places.googleapis.com/v1/places:autocomplete';
const PLACE_DETAILS_URL = 'https://places.googleapis.com/v1/places/';
const GEOCODE_URL = 'https://maps.googleapis.com/maps/api/geocode/json';
const ROUTES_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes';

/** Autocomplete (New) returns at most 5 predictions; each one costs a Place Details call. */
const MAX_PREDICTIONS = 5;
/** locationBias circle radius; the API caps it at 50 km. */
const BIAS_RADIUS_M = 50_000;
/** Place coordinates may be cached (place IDs indefinitely); 24 h keeps the cache small and fresh. */
const DETAILS_TTL_MS = 24 * 60 * 60_000;
const DETAILS_MAX = 2_000;
const TIMEOUT_MS = 5_000;
const MAX_ROUTES = 3;

/**
 * Google Maps Platform adapter: Places API (New) Autocomplete + Place Details for search,
 * Geocoding API for reverse/forward geocoding, Routes API for driving distance and geometry.
 * Every failure (HTTP, quota, denied key, timeout) surfaces as UnavailableMapsError so the
 * switching port can fall back to Mapbox. The key is server-side only and never logged.
 */
export class GoogleMapsPort implements MapsPort {
  private readonly logger = new Logger(GoogleMapsPort.name);
  private readonly details = new Map<string, { at: number; point: GeoPoint }>();
  private readonly fetcher: GoogleFetch;

  constructor(
    private readonly apiKey: string,
    fetcher?: GoogleFetch,
  ) {
    this.fetcher = fetcher ?? ((url, init) => fetch(url, init));
  }

  async geocode(query: string): Promise<GeocodeResult> {
    const url = new URL(GEOCODE_URL);
    url.searchParams.set('address', query);
    url.searchParams.set('region', 'vn');
    url.searchParams.set('language', 'vi');
    const first = (await this.geocodeResults(url))[0];
    if (!first) {
      throw new UnavailableMapsError('Google geocode returned no result');
    }
    return { lat: first.lat, lng: first.lng, label: first.address, provider: 'google' };
  }

  async searchPlaces(query: string, limit: number, near?: GeoPoint): Promise<PlaceSuggestion[]> {
    const input = query.trim();
    if (input.length < 2) {
      return [];
    }
    const body: Record<string, unknown> = {
      input,
      languageCode: 'vi',
      regionCode: 'vn',
      includedRegionCodes: ['vn'],
    };
    if (near) {
      const center = { latitude: near.lat, longitude: near.lng };
      body.locationBias = { circle: { center, radius: BIAS_RADIUS_M } };
      body.origin = center;
    }
    const json = (await this.request(AUTOCOMPLETE_URL, 'POST', {
      fieldMask:
        'suggestions.placePrediction.placeId,suggestions.placePrediction.text.text,' +
        'suggestions.placePrediction.structuredFormat,suggestions.placePrediction.types',
      body,
    })) as AutocompleteJson;
    const predictions = (json?.suggestions ?? [])
      .map((s) => s.placePrediction)
      .filter((p): p is Prediction => typeof p?.placeId === 'string' && p.placeId.length > 0)
      .slice(0, Math.min(Math.max(limit, 1), MAX_PREDICTIONS));
    // Autocomplete has no coordinates; resolve each prediction (cached by place ID).
    const resolved = await Promise.all(
      predictions.map(async (p) => {
        try {
          return { p, point: await this.placeLocation(p.placeId) };
        } catch {
          return { p, point: null };
        }
      }),
    );
    if (predictions.length > 0 && resolved.every((r) => r.point === null)) {
      throw new UnavailableMapsError('Google place details unavailable');
    }
    const out: PlaceSuggestion[] = [];
    for (const { p, point } of resolved) {
      if (!point) continue;
      const full = stripCountry(p.text?.text?.trim() ?? '');
      const main = p.structuredFormat?.mainText?.text?.trim() || full.split(',')[0]?.trim() || '';
      if (!main) continue;
      out.push({
        lat: point.lat,
        lng: point.lng,
        name: main,
        address: full || main,
        provider: 'google',
        kind: googleKind(p.types),
      });
    }
    return out;
  }

  async reverseGeocode(point: GeoPoint): Promise<PlaceSuggestion | null> {
    const url = new URL(GEOCODE_URL);
    url.searchParams.set('latlng', `${point.lat},${point.lng}`);
    url.searchParams.set('language', 'vi');
    url.searchParams.set('region', 'vn');
    const first = (await this.geocodeResults(url))[0];
    return first
      ? { lat: point.lat, lng: point.lng, name: first.name, address: first.address, provider: 'google', kind: first.kind }
      : null;
  }

  async routeDistanceKm(origin: GeoPoint, destination: GeoPoint): Promise<number> {
    const routes = await this.computeRoutes(origin, destination, false);
    const meters = routes[0]?.distanceM;
    if (typeof meters !== 'number' || meters <= 0) {
      throw new UnavailableMapsError('Google routes returned no distance');
    }
    return meters / 1000;
  }

  /** Driving routes (TRAFFIC_UNAWARE keeps the request on the Essentials SKU). */
  async computeRoutes(from: GeoPoint, to: GeoPoint, alternatives = true): Promise<GoogleRoute[]> {
    const json = (await this.request(ROUTES_URL, 'POST', {
      fieldMask:
        'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline,routes.description',
      body: {
        origin: { location: { latLng: { latitude: from.lat, longitude: from.lng } } },
        destination: { location: { latLng: { latitude: to.lat, longitude: to.lng } } },
        travelMode: 'DRIVE',
        routingPreference: 'TRAFFIC_UNAWARE',
        computeAlternativeRoutes: alternatives,
        languageCode: 'vi',
        regionCode: 'vn',
        units: 'METRIC',
      },
    })) as RoutesJson;
    const out: GoogleRoute[] = [];
    for (const r of json?.routes ?? []) {
      const encoded = r.polyline?.encodedPolyline;
      const coords = typeof encoded === 'string' ? decodePolyline(encoded) : [];
      const distanceM = typeof r.distanceMeters === 'number' ? Math.round(r.distanceMeters) : 0;
      if (coords.length < 2 && distanceM <= 0) continue;
      out.push({
        coords,
        distanceM,
        durationSec: parseDurationSec(r.duration),
        summary: typeof r.description === 'string' ? r.description.slice(0, 200) : '',
      });
      if (out.length >= MAX_ROUTES) break;
    }
    return out;
  }

  private async placeLocation(placeId: string): Promise<GeoPoint> {
    const hit = this.details.get(placeId);
    if (hit && Date.now() - hit.at < DETAILS_TTL_MS) {
      return hit.point;
    }
    const json = (await this.request(
      `${PLACE_DETAILS_URL}${encodeURIComponent(placeId)}?languageCode=vi&regionCode=vn`,
      'GET',
      { fieldMask: 'location' },
    )) as { location?: { latitude?: unknown; longitude?: unknown } };
    const lat = json?.location?.latitude;
    const lng = json?.location?.longitude;
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      throw new UnavailableMapsError('Google place details returned no location');
    }
    const point = { lat, lng };
    if (this.details.size >= DETAILS_MAX) {
      this.details.delete(this.details.keys().next().value as string);
    }
    this.details.set(placeId, { at: Date.now(), point });
    return point;
  }

  private async geocodeResults(
    url: URL,
  ): Promise<Array<{ lat: number; lng: number; name: string; address: string; kind: PlaceKind }>> {
    url.searchParams.set('key', this.apiKey);
    const json = (await this.request(url.toString(), 'GET', {})) as GeocodeJson;
    const status = json?.status;
    if (status === 'ZERO_RESULTS') return [];
    if (status !== 'OK') {
      // REQUEST_DENIED / OVER_QUERY_LIMIT / INVALID_REQUEST: let the caller fall back.
      this.logger.warn(`Google geocoding status ${String(status)}`);
      throw new UnavailableMapsError(`Google geocoding status ${String(status)}`);
    }
    const out: Array<{ lat: number; lng: number; name: string; address: string; kind: PlaceKind }> = [];
    for (const r of json.results ?? []) {
      const loc = r.geometry?.location;
      const address = stripCountry(r.formatted_address?.trim() ?? '');
      if (typeof loc?.lat !== 'number' || typeof loc?.lng !== 'number' || !address) continue;
      out.push({
        lat: loc.lat,
        lng: loc.lng,
        name: address.split(',')[0]?.trim() || address,
        address,
        kind: googleKind(r.types),
      });
    }
    return out;
  }

  private async request(
    url: string,
    method: 'GET' | 'POST',
    opts: { fieldMask?: string; body?: unknown },
  ): Promise<unknown> {
    const headers: Record<string, string> = {};
    // Geocoding (legacy web service) takes the key as a query param; Places/Routes take headers.
    if (!url.startsWith(GEOCODE_URL)) {
      headers['X-Goog-Api-Key'] = this.apiKey;
    }
    if (opts.fieldMask) headers['X-Goog-FieldMask'] = opts.fieldMask;
    if (opts.body !== undefined) headers['Content-Type'] = 'application/json';
    try {
      const res = await this.fetcher(url, {
        method,
        headers,
        body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      if (!res.ok) {
        this.logger.warn(`Google Maps HTTP ${res.status}`);
        throw new UnavailableMapsError(`Google Maps HTTP ${res.status}`);
      }
      return await res.json();
    } catch (error) {
      if (error instanceof UnavailableMapsError) throw error;
      this.logger.warn(
        `Google Maps request failed: ${error instanceof Error ? error.name : 'unknown'}`,
      );
      throw new UnavailableMapsError('Google Maps request failed');
    }
  }
}

/** Google labels end with ", Việt Nam"; the app is VN-only so the suffix is noise. */
export function stripCountry(label: string): string {
  return label.replace(/,\s*(Việt Nam|Vietnam)\s*$/i, '').trim();
}

export function googleKind(types: unknown): PlaceKind {
  const list = Array.isArray(types) ? (types as unknown[]).filter((t) => typeof t === 'string') : [];
  if (list.includes('street_address') || list.includes('premise') || list.includes('subpremise')) {
    return 'address';
  }
  if (list.includes('route')) return 'street';
  if (list.includes('establishment') || list.includes('point_of_interest')) return 'poi';
  return 'area';
}

/** Routes API durations are protobuf Duration strings, e.g. "754s". */
export function parseDurationSec(value: unknown): number {
  if (typeof value !== 'string') return 0;
  const n = Number.parseFloat(value.replace(/s$/, ''));
  return Number.isFinite(n) && n > 0 ? Math.round(n) : 0;
}

/** Google encoded polyline (precision 5) → [lat, lng] pairs. */
export function decodePolyline(encoded: string): [number, number][] {
  const out: [number, number][] = [];
  let index = 0;
  let lat = 0;
  let lng = 0;
  while (index < encoded.length) {
    let result = 0;
    let shift = 0;
    let byte: number;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    lat += result & 1 ? ~(result >> 1) : result >> 1;
    result = 0;
    shift = 0;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    lng += result & 1 ? ~(result >> 1) : result >> 1;
    out.push([lat / 1e5, lng / 1e5]);
  }
  return out;
}

type Prediction = {
  placeId: string;
  text?: { text?: string };
  structuredFormat?: { mainText?: { text?: string }; secondaryText?: { text?: string } };
  types?: string[];
};

type AutocompleteJson = { suggestions?: Array<{ placePrediction?: Prediction }> };

type GeocodeJson = {
  status?: string;
  results?: Array<{
    formatted_address?: string;
    types?: string[];
    geometry?: { location?: { lat?: number; lng?: number } };
  }>;
};

type RoutesJson = {
  routes?: Array<{
    distanceMeters?: number;
    duration?: string;
    description?: string;
    polyline?: { encodedPolyline?: string };
  }>;
};
