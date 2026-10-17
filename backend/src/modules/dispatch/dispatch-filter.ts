import { haversineKm } from '../../shared/geo/haversine.js';

export type GeoCoords = { lat: number; lng: number };

export type DispatchQuery = {
  lat?: number;
  lng?: number;
};

/**
 * When lat+lng are present, keep items within radiusKm of the driver's position.
 * When coords are omitted, return a capped recent slice (never unbounded).
 */
export function filterByDispatchRadius<T>(
  items: T[],
  query: DispatchQuery,
  radiusKm: number,
  fallbackLimit: number,
  pointOf: (item: T) => GeoCoords,
): T[] {
  if (
    query.lat === undefined ||
    query.lng === undefined ||
    !Number.isFinite(query.lat) ||
    !Number.isFinite(query.lng)
  ) {
    return items.slice(0, fallbackLimit);
  }
  const origin = { lat: query.lat, lng: query.lng };
  return items
    .filter((item) => haversineKm(origin, pointOf(item)) <= radiusKm)
    .slice(0, fallbackLimit);
}
