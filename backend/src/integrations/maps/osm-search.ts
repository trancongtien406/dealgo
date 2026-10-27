import { Logger } from '@nestjs/common';
import type { GeoPoint, PlaceKind, PlaceSuggestion } from './maps-port.js';

/** Vietnam mainland + islands (minLng, minLat, maxLng, maxLat). */
export const VN_BBOX: readonly [number, number, number, number] = [102.1, 8.4, 109.5, 23.4];

export interface OsmSearchPort {
  /** Matches inside [bbox] (default: Vietnam), biased toward [near]. */
  search(
    query: string,
    limit: number,
    near?: GeoPoint,
    bbox?: readonly [number, number, number, number],
  ): Promise<PlaceSuggestion[]>;
}

type PhotonJson = {
  features?: Array<{
    geometry?: { coordinates?: number[] };
    properties?: {
      name?: string;
      street?: string;
      housenumber?: string;
      district?: string;
      locality?: string;
      city?: string;
      county?: string;
      state?: string;
      osm_key?: string;
      osm_value?: string;
      type?: string;
    };
  }>;
};

/**
 * Photon (komoot) geocoder over OpenStreetMap. Data © OpenStreetMap
 * contributors (ODbL). photon.komoot.io is fair-use only: production points
 * PLACES_OSM_SEARCH_URL at a self-hosted Photon. Failures answer [] so the
 * primary provider still serves the search.
 */
export class PhotonSearchPort implements OsmSearchPort {
  private readonly logger = new Logger(PhotonSearchPort.name);

  constructor(
    private readonly baseUrl: string,
    private readonly timeoutMs = 2_500,
  ) {}

  async search(
    query: string,
    limit: number,
    near?: GeoPoint,
    bbox: readonly [number, number, number, number] = VN_BBOX,
  ): Promise<PlaceSuggestion[]> {
    const url = new URL('/api/', this.baseUrl);
    url.searchParams.set('q', query);
    url.searchParams.set('limit', String(Math.min(Math.max(limit, 1), 15)));
    url.searchParams.set('bbox', bbox.join(','));
    if (near) {
      url.searchParams.set('lat', String(near.lat));
      url.searchParams.set('lon', String(near.lng));
    }
    try {
      const response = await fetch(url, {
        headers: { 'User-Agent': 'DealGo/1.0 (place search)' },
        signal: AbortSignal.timeout(this.timeoutMs),
      });
      if (!response.ok) {
        this.logger.warn(`Photon HTTP ${response.status}`);
        return [];
      }
      return photonToSuggestions((await response.json()) as PhotonJson);
    } catch (error) {
      this.logger.warn(`Photon request failed: ${error instanceof Error ? error.message : 'unknown'}`);
      return [];
    }
  }
}

export function photonToSuggestions(body: PhotonJson): PlaceSuggestion[] {
  const out: PlaceSuggestion[] = [];
  for (const feature of body?.features ?? []) {
    const [lng, lat] = feature.geometry?.coordinates ?? [];
    const p = feature.properties ?? {};
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      continue;
    }
    const kind = photonKind(p.osm_key, p.housenumber);
    const base = p.name?.trim() || p.street?.trim();
    if (!base) {
      continue;
    }
    const name =
      kind === 'address' && p.housenumber && !base.startsWith(p.housenumber)
        ? `${p.housenumber} ${base}`
        : base;
    const area = [p.district ?? p.locality, p.city ?? p.county, p.state]
      .map((part) => part?.trim())
      .filter((part, i, all): part is string => !!part && all.indexOf(part) === i && part !== name);
    out.push({
      lat,
      lng,
      name,
      address: [name, ...area].join(', '),
      provider: 'osm',
      kind,
    });
  }
  return out;
}

function photonKind(osmKey: string | undefined, houseNumber: string | undefined): PlaceKind {
  if (osmKey === 'highway') return 'street';
  if (osmKey === 'place' || osmKey === 'boundary') return 'area';
  if (houseNumber && (osmKey === 'building' || osmKey === 'place' || !osmKey)) return 'address';
  return 'poi';
}
