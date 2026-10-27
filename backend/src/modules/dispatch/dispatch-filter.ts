import { haversineKm } from '../../shared/geo/haversine.js';

export type GeoCoords = { lat: number; lng: number };

export type DispatchQuery = {
  lat?: number;
  lng?: number;
};

export type GeoBox = { minLat: number; maxLat: number; minLng: number; maxLng: number };

/**
 * A lat/lng box that contains the radius circle, so the database can pre-filter
 * open jobs near the driver instead of returning the N soonest-expiring jobs nationwide
 * (which hid nearby jobs in a busy market). Exact distance is still checked afterwards.
 */
export function boundingBox(origin: GeoCoords, radiusKm: number): GeoBox {
  const dLat = radiusKm / 111.32;
  const cos = Math.max(Math.cos((origin.lat * Math.PI) / 180), 0.01);
  const dLng = radiusKm / (111.32 * cos);
  return {
    minLat: origin.lat - dLat,
    maxLat: origin.lat + dLat,
    minLng: origin.lng - dLng,
    maxLng: origin.lng + dLng,
  };
}

export function inBox(point: GeoCoords, box: GeoBox): boolean {
  return (
    point.lat >= box.minLat && point.lat <= box.maxLat && point.lng >= box.minLng && point.lng <= box.maxLng
  );
}

/**
 * When lat+lng are present, keep items within radiusKm of the driver's position, nearest
 * first (sorted before the cap, so the cap keeps the nearest jobs, not the oldest).
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
    .map((item, index) => ({ item, index, km: haversineKm(origin, pointOf(item)) }))
    .filter((row) => row.km <= radiusKm)
    .sort((a, b) => a.km - b.km || a.index - b.index)
    .slice(0, fallbackLimit)
    .map((row) => row.item);
}
