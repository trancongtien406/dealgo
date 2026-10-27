import type { RouteLookup, RoutingProviderName } from './routing.service.js';

/**
 * Compact road geometry for mobile + Admin clients.
 * When `available` is false clients draw NO line (never a straight-line fallback)
 * and show only the pickup/dropoff markers.
 */
export type RouteGeometryView = {
  available: boolean;
  provider: RoutingProviderName;
  /** [lat, lng] pairs along the best road route. Empty when unavailable. */
  coords: [number, number][];
  distanceM: number | null;
  durationSec: number | null;
};

export function toRouteGeometryView(lookup: RouteLookup): RouteGeometryView {
  const best = lookup.available ? lookup.routes[0] : undefined;
  if (!best || best.coords.length < 2) {
    return {
      available: false,
      provider: lookup.provider,
      coords: [],
      distanceM: null,
      durationSec: null,
    };
  }
  return {
    available: true,
    provider: lookup.provider,
    coords: best.coords,
    distanceM: best.distanceM,
    durationSec: best.durationSec,
  };
}

export const UNAVAILABLE_ROUTE_GEOMETRY: RouteGeometryView = {
  available: false,
  provider: 'none',
  coords: [],
  distanceM: null,
  durationSec: null,
};
