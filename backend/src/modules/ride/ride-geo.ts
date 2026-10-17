export { haversineKm, type GeoCoordinate } from '../../shared/geo/haversine.js';

const MAX_STORED_VND = 2_147_483_647;

export function quoteReferenceFareVnd(
  distanceKm: number,
  vndPerKm: number,
  minimumFareVnd: number,
): number {
  if (!Number.isFinite(distanceKm) || distanceKm < 0) {
    return minimumFareVnd;
  }
  const rounded = Math.round(distanceKm * vndPerKm);
  return Math.min(Math.max(minimumFareVnd, rounded), MAX_STORED_VND);
}
