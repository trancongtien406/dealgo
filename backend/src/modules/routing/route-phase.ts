/**
 * Phase-aware route legs (ride + food). No turn-by-turn and no periodic refresh in the
 * app (DEC-PROD-035, owner 2026-10-26): ONE Directions leg per phase, re-looked-up only when the
 * driver drifts off it, throttled. Both numbers are admin settings
 * (ROUTE_OFF_ROUTE_THRESHOLD_M, ROUTE_REROUTE_MIN_INTERVAL_SECONDS); the constants below are
 * the fallbacks when settings are unavailable. Turn-by-turn is handed to Google Maps /
 * Apple Maps / Waze on the driver's phone.
 */
export type RoutePhase = 'APPROACH' | 'TRIP';

/** Default: driver farther than this from the cached leg counts as off-route. */
export const ROUTE_OFF_ROUTE_THRESHOLD_M = 150;
/** Default: never call Directions for the same job more often than this. */
export const ROUTE_MIN_REROUTE_INTERVAL_MS = 120_000;

export function routePhaseForRide(status: string): RoutePhase | null {
  if (status === 'ASSIGNED' || status === 'DRIVER_EN_ROUTE') return 'APPROACH';
  if (status === 'DRIVER_ARRIVED' || status === 'IN_TRIP') return 'TRIP';
  return null;
}

export function routePhaseForFood(status: string): RoutePhase | null {
  if (status === 'ASSIGNED') return 'APPROACH';
  if (status === 'PICKED_UP') return 'TRIP';
  return null;
}

type LatLng = { lat: number; lng: number };

/** Meters from point to polyline ([lat,lng] pairs), equirectangular — fine at city scale. */
export function distanceToPolylineM(point: LatLng, coords: [number, number][]): number {
  if (coords.length === 0) return Number.POSITIVE_INFINITY;
  const R = 6_371_000;
  const k = Math.cos((point.lat * Math.PI) / 180);
  const xy = (lat: number, lng: number) => [
    ((lng - point.lng) * Math.PI * R * k) / 180,
    ((lat - point.lat) * Math.PI * R) / 180,
  ];
  if (coords.length === 1) {
    const [x, y] = xy(coords[0][0], coords[0][1]);
    return Math.hypot(x, y);
  }
  let best = Number.POSITIVE_INFINITY;
  for (let i = 1; i < coords.length; i += 1) {
    const [ax, ay] = xy(coords[i - 1][0], coords[i - 1][1]);
    const [bx, by] = xy(coords[i][0], coords[i][1]);
    const dx = bx - ax;
    const dy = by - ay;
    const len2 = dx * dx + dy * dy;
    const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / len2));
    best = Math.min(best, Math.hypot(ax + t * dx, ay + t * dy));
  }
  return best;
}
