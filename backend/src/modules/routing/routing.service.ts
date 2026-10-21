import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';

export const ROUTING_FETCH = Symbol('ROUTING_FETCH');

export type RoutingProviderName = 'none' | 'osrm' | 'mapbox';

export type RoutePoint = { lat: number; lng: number };

export type RouteOption = {
  /** [lat, lng] pairs, ready for the Admin map. */
  coords: [number, number][];
  distanceM: number;
  durationSec: number;
  summary: string;
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
 * DEC-PROD-045 — road geometry for Admin maps behind a configurable provider.
 * The browser never calls OSRM/Mapbox directly; tokens stay server-side.
 * ROUTING_PROVIDER = none (default) | osrm (ROUTING_OSRM_URL, self-hosted) | mapbox (MAPBOX_DIRECTIONS_TOKEN).
 */
@Injectable()
export class RoutingService {
  private readonly logger = new Logger(RoutingService.name);
  private readonly cache = new Map<string, { at: number; value: RouteLookup }>();
  private readonly fetcher: FetchLike;

  constructor(
    private readonly config: ConfigService<AppEnv, true>,
    @Optional() @Inject(ROUTING_FETCH) fetcher?: FetchLike,
  ) {
    this.fetcher = fetcher ?? ((url, init) => fetch(url, init));
  }

  provider(): RoutingProviderName {
    const raw = (this.config.get('ROUTING_PROVIDER', { infer: true }) ?? '').trim().toLowerCase();
    if (raw === 'osrm' && this.osrmBase()) return 'osrm';
    if (raw === 'mapbox' && this.mapboxToken()) return 'mapbox';
    return 'none';
  }

  async route(from: RoutePoint, to: RoutePoint): Promise<RouteLookup> {
    const provider = this.provider();
    if (provider === 'none') {
      return { provider, available: false, routes: [] };
    }
    const key = `${provider};${from.lat.toFixed(5)},${from.lng.toFixed(5)};${to.lat.toFixed(5)},${to.lng.toFixed(5)}`;
    const hit = this.cache.get(key);
    if (hit && Date.now() - hit.at < CACHE_TTL_MS) {
      return hit.value;
    }
    let routes: RouteOption[] = [];
    try {
      routes = await this.query(provider, from, to);
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
    provider: Exclude<RoutingProviderName, 'none'>,
    from: RoutePoint,
    to: RoutePoint,
  ): Promise<RouteOption[]> {
    const pair = `${from.lng},${from.lat};${to.lng},${to.lat}`;
    const url =
      provider === 'osrm'
        ? `${this.osrmBase()}/route/v1/driving/${pair}?overview=full&geometries=geojson&alternatives=true`
        : `https://api.mapbox.com/directions/v5/mapbox/driving/${pair}?geometries=geojson&overview=full&alternatives=true&access_token=${encodeURIComponent(this.mapboxToken())}`;
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

  private mapboxToken(): string {
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
      legs?: { summary?: unknown }[];
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
    });
    if (out.length >= MAX_ROUTES) break;
  }
  return out;
}
