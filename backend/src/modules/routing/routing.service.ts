import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';
import { MapsProviderSettings } from '../../integrations/maps/maps-provider-settings.js';
import { MapKeysService } from '../../platform/integration-settings/map-keys.service.js';

export const ROUTING_FETCH = Symbol('ROUTING_FETCH');

export type RoutingProviderName = 'none' | 'osrm' | 'mapbox' | 'google';

export type RoutePoint = { lat: number; lng: number };

export type RouteOption = {
  /** [lat, lng] pairs, ready for the Admin map. */
  coords: [number, number][];
  distanceM: number;
  durationSec: number;
  summary: string;
  /** Per-leg distance/duration between consecutive waypoints (multi-stop). */
  legs?: Array<{ distanceM: number; durationSec: number }>;
};

export type RouteLookup = {
  provider: RoutingProviderName;
  /** false = no provider configured or the provider failed; the client draws a straight line. */
  available: boolean;
  routes: RouteOption[];
};

type FetchLike = (url: string, init?: { signal?: AbortSignal }) => Promise<{
  ok: boolean;
  status: number;
  json(): Promise<unknown>;
}>;

const CACHE_MAX = 200;
const CACHE_TTL_MS = 10 * 60_000;
const MAX_ROUTES = 3;

/**
 * DEC-PROD-045 — road geometry for Admin maps and (DRAFT) mobile Ride/Food clients.
 * Browsers and apps never call OSRM/Mapbox directly; tokens stay server-side.
 * ROUTING_PROVIDER = none (code default if unset) | mapbox (preferred when MAPBOX_DIRECTIONS_TOKEN set)
 *   | osrm (ROUTING_OSRM_URL; self-hosted fallback — public demo OSRM is DEV-only).
 * Owner prefers Mapbox when a Directions token is present; do not confuse with
 * NEXT_PUBLIC_MAPBOX_TOKEN (Admin tiles) or a misnamed MAPBOX_ACCESS_TOKEN.
 * Admin › Cài đặt › Bản đồ may switch routing to Google (Routes API) when a Google key is set; a
 * Google failure falls back to the env provider above. The Mapbox server token and Google key set
 * in Admin override env.
 * When unavailable, clients draw a straight pickup→dropoff line with an illustrative watermark.
 */
@Injectable()
export class RoutingService {
  private readonly logger = new Logger(RoutingService.name);
  private readonly cache = new Map<string, { at: number; value: RouteLookup }>();
  private readonly fetcher: FetchLike;

  constructor(
    private readonly config: ConfigService<AppEnv, true>,
    @Optional() @Inject(ROUTING_FETCH) fetcher?: FetchLike,
    @Optional() private readonly mapsProviders?: MapsProviderSettings,
    @Optional() private readonly mapKeys?: MapKeysService,
  ) {
    this.fetcher = fetcher ?? ((url, init) => fetch(url, init));
  }

  /** The env-configured provider (used when Google is not chosen or fails). */
  provider(): Exclude<RoutingProviderName, 'google'> {
    const raw = (this.config.get('ROUTING_PROVIDER', { infer: true }) ?? '').trim().toLowerCase();
    if (raw === 'osrm' && this.osrmBase()) return 'osrm';
    if (raw === 'mapbox' && this.mapboxTokenSnapshot()) return 'mapbox';
    return 'none';
  }

  async route(from: RoutePoint, to: RoutePoint): Promise<RouteLookup> {
    const google = await this.mapsProviders?.googlePort();
    if (google && (await this.mapsProviders?.effective('route')) === 'google') {
      const viaGoogle = await this.cached('google', from, to, async () => {
        const routes = await google.computeRoutes(from, to);
        return routes.filter((r) => r.coords.length >= 2);
      });
      if (viaGoogle.available) return viaGoogle;
    }
    const provider = this.provider();
    if (provider === 'none') {
      return { provider, available: false, routes: [] };
    }
    return this.cached(provider, from, to, () => this.query(provider, [from, to], true));
  }

  /**
   * Road route through every waypoint in order (multi-stop rides). Two points = route().
   * Google Routes is not used for waypoints; Mapbox/OSRM (server key) take up to 25 coordinates.
   */
  async routeVia(points: readonly RoutePoint[]): Promise<RouteLookup> {
    if (points.length < 2) {
      return { provider: this.provider(), available: false, routes: [] };
    }
    if (points.length === 2) {
      return this.route(points[0]!, points[1]!);
    }
    const provider = this.provider();
    if (provider === 'none' || points.length > 25) {
      return { provider, available: false, routes: [] };
    }
    return this.cachedKey(provider, `${provider};via;${points.map(pointKey).join(';')}`, () =>
      this.query(provider, points, false),
    );
  }

  private async cached(
    provider: Exclude<RoutingProviderName, 'none'>,
    from: RoutePoint,
    to: RoutePoint,
    load: () => Promise<RouteOption[]>,
  ): Promise<RouteLookup> {
    return this.cachedKey(provider, `${provider};${pointKey(from)};${pointKey(to)}`, load);
  }

  private async cachedKey(
    provider: Exclude<RoutingProviderName, 'none'>,
    key: string,
    load: () => Promise<RouteOption[]>,
  ): Promise<RouteLookup> {
    const hit = this.cache.get(key);
    if (hit && Date.now() - hit.at < CACHE_TTL_MS) {
      return hit.value;
    }
    let routes: RouteOption[] = [];
    try {
      routes = (await load()).slice(0, MAX_ROUTES);
    } catch (error) {
      this.logger.warn(`Routing via ${provider} failed: ${(error as Error).message}`);
      return { provider, available: false, routes: [] };
    }
    const value: RouteLookup = { provider, available: routes.length > 0, routes };
    if (routes.length) {
      if (this.cache.size >= CACHE_MAX) {
        this.cache.delete(this.cache.keys().next().value as string);
      }
      this.cache.set(key, { at: Date.now(), value });
    }
    return value;
  }

  private async query(
    provider: 'osrm' | 'mapbox',
    points: readonly RoutePoint[],
    alternatives: boolean,
  ): Promise<RouteOption[]> {
    const pair = points.map((point) => `${point.lng},${point.lat}`).join(';');
    const mapboxToken = provider === 'mapbox' ? await this.mapboxToken() : '';
    const url =
      provider === 'osrm'
        ? `${this.osrmBase()}/route/v1/driving/${pair}?overview=full&geometries=geojson&alternatives=${alternatives}`
        : `https://api.mapbox.com/directions/v5/mapbox/driving/${pair}?geometries=geojson&overview=full&alternatives=${alternatives}&access_token=${encodeURIComponent(mapboxToken)}`;
    const timeout = this.config.get('ROUTING_TIMEOUT_MS', { infer: true }) ?? 4000;
    const res = await this.fetcher(url, { signal: AbortSignal.timeout(timeout) });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    return parseDirections(await res.json());
  }

  private osrmBase(): string {
    return (this.config.get('ROUTING_OSRM_URL', { infer: true }) ?? '').trim().replace(/\/+$/, '');
  }

  private async mapboxToken(): Promise<string> {
    if (this.mapKeys) return (await this.mapKeys.effective()).mapboxServerToken;
    return this.envMapboxToken();
  }

  private mapboxTokenSnapshot(): string {
    return this.mapKeys ? this.mapKeys.snapshot().mapboxServerToken : this.envMapboxToken();
  }

  private envMapboxToken(): string {
    return (this.config.get('MAPBOX_DIRECTIONS_TOKEN', { infer: true }) ?? '').trim();
  }
}

/** OSRM and Mapbox Directions share the `routes[].geometry.coordinates` GeoJSON shape. */
export function parseDirections(body: unknown): RouteOption[] {
  const routes = (body as { routes?: unknown })?.routes;
  if (!Array.isArray(routes)) return [];
  const out: RouteOption[] = [];
  for (const raw of routes) {
    const r = raw as {
      geometry?: { coordinates?: unknown };
      distance?: unknown;
      duration?: unknown;
      legs?: { summary?: unknown; distance?: unknown; duration?: unknown }[];
    };
    const coordinates = r?.geometry?.coordinates;
    if (!Array.isArray(coordinates) || coordinates.length < 2) continue;
    const coords: [number, number][] = [];
    for (const point of coordinates) {
      if (
        Array.isArray(point) &&
        typeof point[0] === 'number' &&
        typeof point[1] === 'number' &&
        Number.isFinite(point[0]) &&
        Number.isFinite(point[1])
      ) {
        coords.push([point[1], point[0]]);
      }
    }
    if (coords.length < 2) continue;
    const summary = r.legs?.[0]?.summary;
    out.push({
      coords,
      distanceM: typeof r.distance === 'number' ? Math.round(r.distance) : 0,
      durationSec: typeof r.duration === 'number' ? Math.round(r.duration) : 0,
      summary: typeof summary === 'string' ? summary.slice(0, 200) : '',
      ...(Array.isArray(r.legs) && r.legs.length > 1
        ? {
            legs: r.legs.map((leg) => ({
              distanceM: typeof leg?.distance === 'number' ? Math.round(leg.distance) : 0,
              durationSec: typeof leg?.duration === 'number' ? Math.round(leg.duration) : 0,
            })),
          }
        : {}),
    });
    if (out.length >= MAX_ROUTES) break;
  }
  return out;
}

function pointKey(point: RoutePoint): string {
  return `${point.lat.toFixed(5)},${point.lng.toFixed(5)}`;
}
