import { Inject, Injectable, Optional } from '@nestjs/common';
import { MAPS_PORT, OSM_SEARCH_PORT } from '../../integrations/maps/maps.constants.js';
import {
  UnavailableMapsError,
  foldVietnamese,
  type GeoPoint,
  type MapsPort,
  type PlaceSuggestion,
} from '../../integrations/maps/maps-port.js';
import type { OsmSearchPort } from '../../integrations/maps/osm-search.js';
import { cleanMapboxVnLabel } from '../../integrations/maps/maps-port.js';
import { MapsProviderSettings } from '../../integrations/maps/maps-provider-settings.js';
import { localBbox, parsePlaceQuery, rankPlaces, textScore, type RankedPlace } from './place-ranking.js';

export type PlaceSearchResult = {
  items: RankedPlace[];
  /** False when no maps provider is configured or it failed; the app then shows saved/recent only. */
  available: boolean;
  /** 'google' when the items come from Google Maps: clients must show the "Google Maps" attribution. */
  attribution?: 'google';
};

const DEFAULT_LIMIT = 8;

/**
 * Search answers are reused for the same folded query within ~1 km
 * (2-decimal proximity) for 10 minutes. Kept short: Mapbox temporary
 * geocoding results may not be stored.
 */
const SEARCH_CACHE_MAX = 500;
const SEARCH_CACHE_TTL_MS = 10 * 60 * 1000;

/** ~11 m cells: a pin dragged a few metres reuses the provider's answer. */
const REVERSE_CELL_DECIMALS = 4;
const REVERSE_CACHE_MAX = 1000;
const REVERSE_CACHE_TTL_MS = 60 * 60 * 1000;

type ReverseEntry = {
  place: PlaceSuggestion | null;
  at: number;
  /** The provider echoed the requested fix, so a hit echoes the new one. */
  keepsFix: boolean;
};

/** Free-text place search on the admin-chosen maps provider (Mapbox / Google; mock in dev). */
@Injectable()
export class PlacesService {
  constructor(
    @Inject(MAPS_PORT) private readonly maps: MapsPort,
    @Optional() @Inject(OSM_SEARCH_PORT) private readonly osm: OsmSearchPort | null = null,
    @Optional() private readonly providers: MapsProviderSettings | null = null,
  ) {}

  /** Cache-key prefix so switching provider in Admin never serves the other provider's answers. */
  private async providerTag(capability: 'search' | 'reverse'): Promise<string> {
    return this.providers ? this.providers.effective(capability) : 'primary';
  }

  private readonly searchCache = new Map<string, { result: PlaceSearchResult; at: number }>();

  /** Clock seam for the reverse cache TTL. */
  now: () => number = () => Date.now();

  private readonly reverseCache = new Map<string, ReverseEntry>();

  /**
   * Nearest address for a GPS fix ({ place: null } when unknown or no provider).
   * Answers are cached per ~11 m cell for an hour (LRU, 1000 cells); an
   * unavailable provider is never cached.
   */
  async reverse(
    lat: number,
    lng: number,
  ): Promise<{ place: PlaceSuggestion | null; available: boolean }> {
    const key = `${await this.providerTag('reverse')}|${lat.toFixed(REVERSE_CELL_DECIMALS)},${lng.toFixed(REVERSE_CELL_DECIMALS)}`;
    const hit = this.reverseCache.get(key);
    if (hit && this.now() - hit.at < REVERSE_CACHE_TTL_MS) {
      this.reverseCache.delete(key);
      this.reverseCache.set(key, hit);
      const place =
        hit.place && hit.keepsFix ? { ...hit.place, lat, lng } : hit.place;
      return { place, available: true };
    }
    try {
      const [raw, osmNear] = await Promise.all([
        this.maps.reverseGeocode({ lat, lng }),
        this.osmReverse({ lat, lng }),
      ]);
      // Same VN cleanup for every provider (Google/Mapbox): no postal codes,
      // no "Việt Nam", accented district names.
      const primary = raw
        ? { ...raw, name: cleanMapboxVnLabel(raw.name) || raw.name, address: cleanMapboxVnLabel(raw.address ?? '') }
        : null;
      const place = mergeReverse({ lat, lng }, primary, osmNear);
      this.reverseCache.delete(key);
      this.reverseCache.set(key, {
        place,
        at: this.now(),
        keepsFix: place != null && place.lat === lat && place.lng === lng,
      });
      while (this.reverseCache.size > REVERSE_CACHE_MAX) {
        const oldest = this.reverseCache.keys().next().value;
        if (oldest === undefined) break;
        this.reverseCache.delete(oldest);
      }
      return { place, available: true };
    } catch (error) {
      if (error instanceof UnavailableMapsError) {
        return { place: null, available: false };
      }
      throw error;
    }
  }

  /** OSM (self-hosted Photon) neighbours of a fix; [] when not configured or failing. */
  private async osmReverse(point: GeoPoint): Promise<PlaceSuggestion[]> {
    if (!this.osm?.reverse) return [];
    try {
      return await this.osm.reverse(point, 5);
    } catch {
      return [];
    }
  }

  /**
   * Place search: the maps provider (Mapbox, or Google when chosen in Admin) plus, when configured, OSM
   * (Photon) streets — first inside ~50 km of [near], then nationwide —
   * re-ranked city first, then nearby provinces, then the country, with
   * diacritic-insensitive text matching. "12 Nguyễn Hoàng" searches the street
   * and returns "12 Nguyễn Hoàng, …" on it flagged approximate when no
   * provider knows the house.
   */
  async search(
    query: string,
    limit = DEFAULT_LIMIT,
    near?: GeoPoint,
  ): Promise<PlaceSearchResult> {
    const parsed = parsePlaceQuery(query);
    if (parsed.raw.length < 2 || parsed.street.length < 2) {
      return { items: [], available: true };
    }
    const key = `${await this.providerTag('search')}|${foldVietnamese(parsed.raw)}|${near ? `${near.lat.toFixed(2)},${near.lng.toFixed(2)}` : '-'}|${limit}`;
    const hit = this.searchCache.get(key);
    if (hit && this.now() - hit.at < SEARCH_CACHE_TTL_MS) {
      this.searchCache.delete(key);
      this.searchCache.set(key, hit);
      return hit.result;
    }
    const [primary, osm] = await Promise.all([
      this.maps.searchPlaces(parsed.raw, 10, near).then(
        (items) => ({ items, available: true }),
        (error: unknown) => {
          if (error instanceof UnavailableMapsError) return { items: [] as PlaceSuggestion[], available: false };
          throw error;
        },
      ),
      this.searchOsm(parsed.street, near, parsed),
    ]);
    const available = primary.available || this.osm != null;
    // Google's terms forbid mixing its results with other sources in one list, so when Google
    // answered, OSM (Photon) is only the fallback for an empty or failed Google answer.
    const fromGoogle = primary.items.some((p) => p.provider === 'google');
    const result: PlaceSearchResult = {
      items: rankPlaces(fromGoogle ? primary.items : [...primary.items, ...osm], parsed, near, limit),
      available,
      ...(fromGoogle ? { attribution: 'google' as const } : {}),
    };
    if (available) {
      this.searchCache.delete(key);
      this.searchCache.set(key, { result, at: this.now() });
      while (this.searchCache.size > SEARCH_CACHE_MAX) {
        const oldest = this.searchCache.keys().next().value;
        if (oldest === undefined) break;
        this.searchCache.delete(oldest);
      }
    }
    return result;
  }

  /** City pass first (~50 km box); nationwide only when it has no text match. */
  private async searchOsm(
    street: string,
    near: GeoPoint | undefined,
    parsed: ReturnType<typeof parsePlaceQuery>,
  ): Promise<PlaceSuggestion[]> {
    const osm = this.osm;
    if (!osm) return [];
    if (near) {
      const local = await osm.search(street, 10, near, localBbox(near));
      if (local.some((place) => textScore(place, parsed) > 0)) {
        return local;
      }
    }
    return osm.search(street, 10, near);
  }
}

/** A house number this close to the pin names the pin ("34 Mỹ Đa Đông 7"). */
export const REVERSE_HOUSE_MAX_M = 40;

function distanceM(a: GeoPoint, b: GeoPoint): number {
  const r = 6_371_000;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(h));
}

/**
 * Mapbox's VN data has streets but almost no house numbers, so a pin only got
 * "Đường X, Phường, Quận". OSM (Photon) often knows the nearest house: use it
 * as the primary line ("34 Đường X") and keep the provider's ward/district/city
 * tail. Without a nearby house number, the provider's street answer stays; with
 * no provider answer, OSM's nearest street/place is the fallback. The pin's
 * own coordinates are kept — only the label is borrowed.
 */
export function mergeReverse(
  fix: GeoPoint,
  primary: PlaceSuggestion | null,
  osmNear: readonly PlaceSuggestion[],
): PlaceSuggestion | null {
  const house = osmNear
    .filter((p) => p.kind === 'address' && /^\S*\d/.test(p.name))
    .map((p) => ({ p, d: distanceM(fix, p) }))
    .filter((x) => x.d <= REVERSE_HOUSE_MAX_M)
    .sort((a, b) => a.d - b.d)[0]?.p;
  const primaryHasNumber = primary != null && /^\d/.test(primary.name.trim());
  if (house && !primaryHasNumber) {
    const name = cleanMapboxVnLabel(house.name) || house.name;
    const tail = primary
      ? cleanMapboxVnLabel(primary.address ?? '')
          .split(',')
          .map((s) => s.trim())
          .filter((s) => s.length > 0 && s !== primary.name && !foldVietnamese(name).includes(foldVietnamese(s)))
      : cleanMapboxVnLabel(house.address ?? '')
          .split(',')
          .map((s) => s.trim())
          .filter((s) => s.length > 0 && s !== name);
    return {
      lat: fix.lat,
      lng: fix.lng,
      name,
      address: [name, ...tail].join(', '),
      provider: primary?.provider ?? house.provider,
      kind: 'address',
    };
  }
  if (primary) return primary;
  const street = osmNear.find((p) => p.kind === 'street' || p.kind === 'address' || p.kind === 'poi');
  return street
    ? { ...street, lat: fix.lat, lng: fix.lng, name: cleanMapboxVnLabel(street.name) || street.name, address: cleanMapboxVnLabel(street.address ?? '') }
    : null;
}
