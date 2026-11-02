import { Injectable, Logger } from '@nestjs/common';
import { haversineKm } from '../../shared/geo/haversine.js';
import { MOCK_DANANG_CENTER, MOCK_DANANG_LANDMARKS } from './maps.constants.js';

export type GeoPoint = { lat: number; lng: number };

export type GeocodeResult = {
  lat: number;
  lng: number;
  label: string;
  provider: 'mock' | 'mapbox' | 'goong' | 'google' | 'osm';
};

/** What a suggestion points at; decides house-number handling and ranking. */
export type PlaceKind = 'address' | 'street' | 'poi' | 'area';

export type PlaceSuggestion = {
  lat: number;
  lng: number;
  /** Short name shown as the title (e.g. "Chợ Hàn"). */
  name: string;
  /** Full address line. */
  address: string;
  provider: GeocodeResult['provider'];
  kind?: PlaceKind;
  /**
   * True when the point is the street, not the house: the user typed a house
   * number the provider does not know, so the app asks them to confirm the pin.
   */
  approximate?: boolean;
};

export interface MapsPort {
  geocode(query: string): Promise<GeocodeResult>;
  /** Up to `limit` matches for a free-text query; [] when nothing matches. */
  searchPlaces(
    query: string,
    limit: number,
    near?: GeoPoint,
  ): Promise<PlaceSuggestion[]>;
  /** Nearest address for a GPS fix; null when the provider has nothing there. */
  reverseGeocode(point: GeoPoint): Promise<PlaceSuggestion | null>;
  routeDistanceKm(origin: GeoPoint, destination: GeoPoint): Promise<number>;
}

export class UnavailableMapsError extends Error {
  constructor(message = 'Maps provider is not configured') {
    super(message);
    this.name = 'UnavailableMapsError';
  }
}

/**
 * Port whose API key is resolved per call (Admin key in DB over env); one inner port per key.
 * An empty key behaves as UnavailableMapsPort.
 */
export class KeyedMapsPort implements MapsPort {
  private cached: { key: string; port: MapsPort } | null = null;

  constructor(
    private readonly resolveKey: () => Promise<string>,
    private readonly create: (key: string) => MapsPort,
  ) {}

  async geocode(query: string): Promise<GeocodeResult> {
    return (await this.port()).geocode(query);
  }

  async searchPlaces(
    query: string,
    limit: number,
    near?: GeoPoint,
  ): Promise<PlaceSuggestion[]> {
    return (await this.port()).searchPlaces(query, limit, near);
  }

  async reverseGeocode(point: GeoPoint): Promise<PlaceSuggestion | null> {
    return (await this.port()).reverseGeocode(point);
  }

  async routeDistanceKm(
    origin: GeoPoint,
    destination: GeoPoint,
  ): Promise<number> {
    return (await this.port()).routeDistanceKm(origin, destination);
  }

  private async port(): Promise<MapsPort> {
    const key = (await this.resolveKey()).trim();
    if (!key) return new UnavailableMapsPort();
    if (this.cached?.key !== key) this.cached = { key, port: this.create(key) };
    return this.cached.port;
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

  async searchPlaces(query: string, limit: number): Promise<PlaceSuggestion[]> {
    const needle = foldVietnamese(query);
    if (!needle) {
      return [];
    }
    return MOCK_DANANG_LANDMARKS.filter(
      (landmark) =>
        foldVietnamese(landmark.label).includes(needle) ||
        foldVietnamese(landmark.address ?? '').includes(needle) ||
        landmark.keywords.some((keyword) => {
          const folded = foldVietnamese(keyword);
          return folded.includes(needle) || needle.includes(folded);
        }),
    )
      .slice(0, limit)
      .map((landmark) => ({
        lat: landmark.lat,
        lng: landmark.lng,
        name: landmark.name ?? landmark.label,
        address: landmark.address ?? landmark.label,
        provider: 'mock' as const,
      }));
  }

  async reverseGeocode(point: GeoPoint): Promise<PlaceSuggestion | null> {
    let best: (typeof MOCK_DANANG_LANDMARKS)[number] | null = null;
    let bestKm = MOCK_REVERSE_RADIUS_KM;
    for (const landmark of MOCK_DANANG_LANDMARKS) {
      const km = haversineKm(point, landmark);
      if (km <= bestKm) {
        best = landmark;
        bestKm = km;
      }
    }
    if (!best) {
      return null;
    }
    return {
      lat: point.lat,
      lng: point.lng,
      name: `Gần ${best.name ?? best.label}`,
      address: best.address ?? best.label,
      provider: 'mock',
    };
  }

  async routeDistanceKm(
    origin: GeoPoint,
    destination: GeoPoint,
  ): Promise<number> {
    return haversineKm(origin, destination);
  }
}

/** Mock reverse geocoding only names a GPS fix this close to a known landmark. */
const MOCK_REVERSE_RADIUS_KM = 0.5;

/** Lower-case, strip Vietnamese diacritics (đ → d) and collapse spaces for matching. */
export function foldVietnamese(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/gi, 'd')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

@Injectable()
export class UnavailableMapsPort implements MapsPort {
  async geocode(_query: string): Promise<GeocodeResult> {
    throw new UnavailableMapsError();
  }

  async searchPlaces(
    _query: string,
    _limit: number,
  ): Promise<PlaceSuggestion[]> {
    throw new UnavailableMapsError();
  }

  async reverseGeocode(_point: GeoPoint): Promise<PlaceSuggestion | null> {
    throw new UnavailableMapsError();
  }

  async routeDistanceKm(
    _origin: GeoPoint,
    _destination: GeoPoint,
  ): Promise<number> {
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

  async searchPlaces(query: string, limit: number): Promise<PlaceSuggestion[]> {
    const url = new URL('https://rsapi.goong.io/geocode');
    url.searchParams.set('address', query);
    url.searchParams.set('api_key', this.apiKey);
    return toSuggestions(await this.fetchJson(url), limit, 'goong');
  }

  async reverseGeocode(point: GeoPoint): Promise<PlaceSuggestion | null> {
    const url = new URL('https://rsapi.goong.io/Geocode');
    url.searchParams.set('latlng', `${point.lat},${point.lng}`);
    url.searchParams.set('api_key', this.apiKey);
    return toSuggestions(await this.fetchJson(url), 1, 'goong')[0] ?? null;
  }

  async routeDistanceKm(
    origin: GeoPoint,
    destination: GeoPoint,
  ): Promise<number> {
    const url = new URL('https://rsapi.goong.io/DistanceMatrix');
    url.searchParams.set('origins', `${origin.lat},${origin.lng}`);
    url.searchParams.set(
      'destinations',
      `${destination.lat},${destination.lng}`,
    );
    url.searchParams.set('vehicle', 'bike');
    url.searchParams.set('api_key', this.apiKey);
    const body = await this.fetchJson(url);
    const meters = body?.rows?.[0]?.elements?.[0]?.distance?.value;
    if (typeof meters !== 'number' || !Number.isFinite(meters) || meters < 0) {
      throw new UnavailableMapsError(
        'Goong distance matrix returned no distance',
      );
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
      this.logger.warn(
        `Goong request failed: ${error instanceof Error ? error.message : 'unknown'}`,
      );
      throw new UnavailableMapsError('Goong request failed');
    }
  }
}

/**
 * Mapbox Geocoding + Directions distance. Uses MAPBOX_ACCESS_TOKEN (pk.*).
 * Prefer this when the product already standardizes on Mapbox tiles/routing.
 * Network/API failures surface as UnavailableMapsError so callers may fall back.
 */
@Injectable()
export class MapboxMapsPort implements MapsPort {
  private readonly logger = new Logger(MapboxMapsPort.name);

  constructor(private readonly accessToken: string) {}

  async geocode(query: string): Promise<GeocodeResult> {
    const features = await this.forward(query, 1);
    const first = features[0];
    if (!first) {
      throw new UnavailableMapsError('Mapbox geocode returned no result');
    }
    return {
      lat: first.lat,
      lng: first.lng,
      label: first.address || first.name,
      provider: 'mapbox',
    };
  }

  async searchPlaces(
    query: string,
    limit: number,
    near?: GeoPoint,
  ): Promise<PlaceSuggestion[]> {
    return this.forward(query, limit, near);
  }

  async reverseGeocode(point: GeoPoint): Promise<PlaceSuggestion | null> {
    const url = new URL(
      `https://api.mapbox.com/geocoding/v5/mapbox.places/${point.lng},${point.lat}.json`,
    );
    url.searchParams.set('access_token', this.accessToken);
    url.searchParams.set('language', 'vi');
    url.searchParams.set('country', 'vn');
    url.searchParams.set('limit', '1');
    url.searchParams.set('types', 'address,poi,place,locality,neighborhood');
    const body = await this.fetchJson(url);
    return mapboxFeaturesToSuggestions(body, 1)[0] ?? null;
  }

  async routeDistanceKm(
    origin: GeoPoint,
    destination: GeoPoint,
  ): Promise<number> {
    const pair = `${origin.lng},${origin.lat};${destination.lng},${destination.lat}`;
    const drivingUrl = new URL(
      `https://api.mapbox.com/directions/v5/mapbox/driving/${pair}`,
    );
    drivingUrl.searchParams.set('access_token', this.accessToken);
    drivingUrl.searchParams.set('overview', 'false');
    drivingUrl.searchParams.set('alternatives', 'true');

    const cyclingUrl = new URL(
      `https://api.mapbox.com/directions/v5/mapbox/cycling/${pair}`,
    );
    cyclingUrl.searchParams.set('access_token', this.accessToken);
    cyclingUrl.searchParams.set('overview', 'false');
    cyclingUrl.searchParams.set('alternatives', 'true');

    const [drivingRes, cyclingRes] = await Promise.all([
      this.fetchJson(drivingUrl).catch(() => null),
      this.fetchJson(cyclingUrl).catch(() => null),
    ]);

    const candidates: number[] = [];
    for (const res of [drivingRes, cyclingRes]) {
      if (res?.routes && Array.isArray(res.routes)) {
        for (const route of res.routes) {
          if (
            typeof route.distance === 'number' &&
            Number.isFinite(route.distance) &&
            route.distance > 0
          ) {
            candidates.push(route.distance);
          }
        }
      }
    }

    if (candidates.length === 0) {
      throw new UnavailableMapsError('Mapbox directions returned no distance');
    }
    return Math.min(...candidates) / 1000;
  }

  private async forward(
    query: string,
    limit: number,
    near?: GeoPoint,
  ): Promise<PlaceSuggestion[]> {
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      return [];
    }
    const url = new URL(
      `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(trimmed)}.json`,
    );
    url.searchParams.set('access_token', this.accessToken);
    url.searchParams.set('language', 'vi');
    url.searchParams.set('country', 'vn');
    url.searchParams.set('limit', String(Math.min(Math.max(limit, 1), 10)));
    url.searchParams.set('types', 'address,poi,place,locality,neighborhood');
    // Bias toward the rider's own location (Grab/Uber-style "near me" ranking);
    // fall back to Mapbox IP-based proximity when the app has no fix.
    url.searchParams.set('proximity', near ? `${near.lng},${near.lat}` : 'ip');
    return mapboxFeaturesToSuggestions(await this.fetchJson(url), limit);
  }

  private async fetchJson(url: URL): Promise<MapboxJson> {
    try {
      const response = await fetch(url, {
        method: 'GET',
        signal: AbortSignal.timeout(5_000),
      });
      if (!response.ok) {
        this.logger.warn(`Mapbox HTTP ${response.status}`);
        throw new UnavailableMapsError(`Mapbox HTTP ${response.status}`);
      }
      return (await response.json()) as MapboxJson;
    } catch (error) {
      if (error instanceof UnavailableMapsError) {
        throw error;
      }
      this.logger.warn(
        `Mapbox request failed: ${error instanceof Error ? error.message : 'unknown'}`,
      );
      throw new UnavailableMapsError('Mapbox request failed');
    }
  }
}

/**
 * Mapbox's VN dataset carries some street names with a Malay "Jalan " prefix
 * (e.g. "Jalan Nguyen Hue" for Nguyễn Huệ, Q.1). Strip it so labels read as Vietnamese.
 */
export function cleanMapboxVnLabel(label: string): string {
  const parts = label
    .replace(/(^|,\s*)Jalan\s+/g, '$1')
    .split(',')
    .map((part) =>
      part
        .trim()
        // Postal codes ("Đà Nẵng 550000", "550000") are noise on a rider label.
        .replace(/\s*\b\d{5,6}\b\s*$/, '')
        // Leading postal code too ("50200 Hai Chau").
        .replace(/^\d{5,6}\s+/, '')
        .trim(),
    )
    .filter((part) => part.length > 0 && !/^(Việt Nam|Vietnam)$/i.test(part))
    .map((part) => VN_UNACCENTED_AREAS[part.toLowerCase()] ?? part);
  return parts.join(', ');
}

/**
 * Areas Mapbox's VN data sometimes returns without diacritics even with
 * language=vi (QA C6: "Hai Chau"). Đà Nẵng, TP.HCM and Hà Nội districts + city names;
 * whole comma-separated segments only. Keep in sync with mobile place.dart.
 */
const VN_UNACCENTED_AREAS: Record<string, string> = {
  'ba dinh': 'Ba Đình',
  'bac tu liem': 'Bắc Từ Liêm',
  'binh chanh': 'Bình Chánh',
  'binh tan': 'Bình Tân',
  'binh thanh': 'Bình Thạnh',
  'cam le': 'Cẩm Lệ',
  'can gio': 'Cần Giờ',
  'cau giay': 'Cầu Giấy',
  'cu chi': 'Củ Chi',
  'da nang': 'Đà Nẵng',
  'da nang city': 'Đà Nẵng',
  danang: 'Đà Nẵng',
  'district 1': 'Quận 1',
  'district 10': 'Quận 10',
  'district 11': 'Quận 11',
  'district 12': 'Quận 12',
  'district 2': 'Quận 2',
  'district 3': 'Quận 3',
  'district 4': 'Quận 4',
  'district 5': 'Quận 5',
  'district 6': 'Quận 6',
  'district 7': 'Quận 7',
  'district 8': 'Quận 8',
  'district 9': 'Quận 9',
  'dong anh': 'Đông Anh',
  'dong da': 'Đống Đa',
  'gia lam': 'Gia Lâm',
  'go vap': 'Gò Vấp',
  'ha dong': 'Hà Đông',
  'ha noi': 'Hà Nội',
  'hai ba trung': 'Hai Bà Trưng',
  'hai chau': 'Hải Châu',
  hanoi: 'Hà Nội',
  'hoi an': 'Hội An',
  'hoi an dong': 'Hội An Đông',
  'hoi an tay': 'Hội An Tây',
  'ho chi minh': 'Hồ Chí Minh',
  'ho chi minh city': 'Thành phố Hồ Chí Minh',
  'hoa vang': 'Hòa Vang',
  'hoan kiem': 'Hoàn Kiếm',
  'hoang mai': 'Hoàng Mai',
  'hoc mon': 'Hóc Môn',
  'huyen binh chanh': 'Huyện Bình Chánh',
  'huyen can gio': 'Huyện Cần Giờ',
  'huyen cu chi': 'Huyện Củ Chi',
  'huyen dong anh': 'Huyện Đông Anh',
  'huyen gia lam': 'Huyện Gia Lâm',
  'huyen hoa vang': 'Huyện Hòa Vang',
  'huyen hoc mon': 'Huyện Hóc Môn',
  'huyen me linh': 'Huyện Mê Linh',
  'huyen nha be': 'Huyện Nhà Bè',
  'huyen soc son': 'Huyện Sóc Sơn',
  'huyen thanh tri': 'Huyện Thanh Trì',
  'lien chieu': 'Liên Chiểu',
  'long bien': 'Long Biên',
  'me linh': 'Mê Linh',
  'nam tu liem': 'Nam Từ Liêm',
  'ngu hanh son': 'Ngũ Hành Sơn',
  'nha be': 'Nhà Bè',
  'phu nhuan': 'Phú Nhuận',
  'quan 1': 'Quận 1',
  'quan 10': 'Quận 10',
  'quan 11': 'Quận 11',
  'quan 12': 'Quận 12',
  'quan 2': 'Quận 2',
  'quan 3': 'Quận 3',
  'quan 4': 'Quận 4',
  'quan 5': 'Quận 5',
  'quan 6': 'Quận 6',
  'quan 7': 'Quận 7',
  'quan 8': 'Quận 8',
  'quan 9': 'Quận 9',
  'quan ba dinh': 'Quận Ba Đình',
  'quan bac tu liem': 'Quận Bắc Từ Liêm',
  'quan binh tan': 'Quận Bình Tân',
  'quan binh thanh': 'Quận Bình Thạnh',
  'quan cam le': 'Quận Cẩm Lệ',
  'quan cau giay': 'Quận Cầu Giấy',
  'quan dong da': 'Quận Đống Đa',
  'quan go vap': 'Quận Gò Vấp',
  'quan ha dong': 'Quận Hà Đông',
  'quan hai ba trung': 'Quận Hai Bà Trưng',
  'quan hai chau': 'Quận Hải Châu',
  'quan hoan kiem': 'Quận Hoàn Kiếm',
  'quan hoang mai': 'Quận Hoàng Mai',
  'quan lien chieu': 'Quận Liên Chiểu',
  'quan long bien': 'Quận Long Biên',
  'quan nam tu liem': 'Quận Nam Từ Liêm',
  'quan ngu hanh son': 'Quận Ngũ Hành Sơn',
  'quan phu nhuan': 'Quận Phú Nhuận',
  'quan son tra': 'Quận Sơn Trà',
  'quan tan binh': 'Quận Tân Bình',
  'quan tan phu': 'Quận Tân Phú',
  'quan tay ho': 'Quận Tây Hồ',
  'quan thanh khe': 'Quận Thanh Khê',
  'quan thanh xuan': 'Quận Thanh Xuân',
  'sai gon': 'Sài Gòn',
  saigon: 'Sài Gòn',
  'soc son': 'Sóc Sơn',
  'son tay': 'Sơn Tây',
  'son tra': 'Sơn Trà',
  'tan binh': 'Tân Bình',
  'tan phu': 'Tân Phú',
  'tay ho': 'Tây Hồ',
  'thanh khe': 'Thanh Khê',
  'thanh pho ha noi': 'Thành phố Hà Nội',
  'thanh pho ho chi minh': 'Thành phố Hồ Chí Minh',
  'thanh pho thu duc': 'Thành phố Thủ Đức',
  'thanh tri': 'Thanh Trì',
  'thanh xuan': 'Thanh Xuân',
  'thi xa son tay': 'Thị xã Sơn Tây',
  'thu duc': 'Thủ Đức',
  'tp ho chi minh': 'TP. Hồ Chí Minh',
  'tp. ho chi minh': 'TP. Hồ Chí Minh',
};

function mapboxFeaturesToSuggestions(
  body: MapboxJson,
  limit: number,
): PlaceSuggestion[] {
  const out: PlaceSuggestion[] = [];
  for (const feature of body?.features ?? []) {
    const center = feature.center;
    if (!Array.isArray(center) || center.length < 2) {
      continue;
    }
    const lng = center[0];
    const lat = center[1];
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      continue;
    }
    const placeName = cleanMapboxVnLabel(feature.place_name?.trim() || '');
    const text = cleanMapboxVnLabel(feature.text?.trim() || '');
    const name = text || placeName.split(',')[0]?.trim() || placeName;
    if (!name) {
      continue;
    }
    const number =
      feature.place_type?.[0] === 'address'
        ? feature.address?.trim()
        : undefined;
    out.push({
      lat,
      lng,
      name: number && !name.startsWith(number) ? `${number} ${name}` : name,
      address: placeName || name,
      provider: 'mapbox',
      kind: mapboxKind(feature),
    });
    if (out.length >= limit) {
      break;
    }
  }
  return out;
}

function toSuggestions(
  body: MapsProviderJson,
  limit: number,
  provider: 'goong',
): PlaceSuggestion[] {
  const out: PlaceSuggestion[] = [];
  for (const result of body?.results ?? []) {
    const location = result.geometry?.location;
    const address = result.formatted_address;
    if (
      typeof location?.lat !== 'number' ||
      typeof location?.lng !== 'number' ||
      !address
    ) {
      continue;
    }
    const name = result.name?.trim() || address.split(',')[0].trim();
    out.push({ lat: location.lat, lng: location.lng, name, address, provider });
    if (out.length >= limit) {
      break;
    }
  }
  return out;
}

function mapboxKind(feature: {
  place_type?: string[];
  address?: string;
}): PlaceKind {
  const type = feature.place_type?.[0];
  if (type === 'address') {
    return feature.address ? 'address' : 'street';
  }
  return type === 'poi' ? 'poi' : 'area';
}

type MapboxJson = {
  features?: Array<{
    place_type?: string[];
    address?: string;
    text?: string;
    place_name?: string;
    center?: number[];
  }>;
  routes?: Array<{ distance?: number }>;
};

type MapsProviderJson = {
  results?: Array<{
    name?: string;
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
