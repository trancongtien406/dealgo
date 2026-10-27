export type DriverPresenceView = {
  userId: string;
  online: boolean;
  rideEnabled: boolean;
  foodEnabled: boolean;
  lat: number | null;
  lng: number | null;
  /** When lat/lng were last reported; null when never. */
  locationAt: Date | null;
  serviceRegionCode?: string | null;
  updatedAt: Date;
};

/** A driver position recent enough to show on a customer's map. */
export type DriverLocation = { lat: number; lng: number; at: Date };

/** DEC-PROD-031: assigned driver's live position for the customer (null when stale/unknown). */
export type DriverLocationResponse = {
  location: { lat: number; lng: number; at: string } | null;
};

/** DEC-PROD-031: positions older than this are not shown to customers. */
export const DRIVER_LOCATION_FRESH_MS = 2 * 60 * 1000;

/**
 * Job pushes (new ride request, ready food order) also reach online drivers whose app is
 * backgrounded or killed: iOS stops location reports soon after the app leaves the screen, so
 * the last position may be older than DRIVER_LOCATION_FRESH_MS. A driver who stayed online and
 * reported within this window still gets the push; the socket list keeps the 2-minute rule.
 */
export const DRIVER_PUSH_LOCATION_MAX_AGE_MS = 30 * 60 * 1000;

export type DispatchService = 'RIDE' | 'FOOD';

export type UpsertPresenceInput = {
  online: boolean;
  /** Omitted keeps the stored choice (true for a new row). */
  rideEnabled?: boolean;
  foodEnabled?: boolean;
  lat?: number;
  lng?: number;
};

export interface DriverPresenceRepository {
  upsert(userId: string, input: UpsertPresenceInput): Promise<DriverPresenceView>;
  findByUserId(userId: string): Promise<DriverPresenceView | null>;
  /** Stores a position without touching online/service toggles. */
  updateLocation(userId: string, location: DriverLocation): Promise<DriverPresenceView>;
  /**
   * Online drivers with that service on and a position reported since
   * `freshSince`, inside a lat/lng box around a point (caller refines by haversine).
   */
  listOnlineNear(input: {
    service: DispatchService;
    lat: number;
    lng: number;
    radiusKm: number;
    freshSince: Date;
    limit: number;
  }): Promise<DriverPresenceView[]>;
}

/** Degrees of latitude/longitude spanning `radiusKm` around `lat` (bounding box pre-filter). */
export function radiusBox(lat: number, lng: number, radiusKm: number) {
  const dLat = radiusKm / 111.32;
  const dLng = radiusKm / (111.32 * Math.max(Math.cos((lat * Math.PI) / 180), 0.01));
  return { minLat: lat - dLat, maxLat: lat + dLat, minLng: lng - dLng, maxLng: lng + dLng };
}

export class MemoryDriverPresenceRepository implements DriverPresenceRepository {
  private readonly rows = new Map<string, DriverPresenceView>();

  async upsert(userId: string, input: UpsertPresenceInput): Promise<DriverPresenceView> {
    const existing = this.rows.get(userId);
    const next: DriverPresenceView = {
      userId,
      online: input.online,
      rideEnabled: input.rideEnabled ?? existing?.rideEnabled ?? true,
      foodEnabled: input.foodEnabled ?? existing?.foodEnabled ?? true,
      lat: input.lat !== undefined ? input.lat : (existing?.lat ?? null),
      lng: input.lng !== undefined ? input.lng : (existing?.lng ?? null),
      locationAt:
        input.lat !== undefined && input.lng !== undefined
          ? new Date()
          : (existing?.locationAt ?? null),
      updatedAt: new Date(),
    };
    this.rows.set(userId, next);
    return { ...next };
  }

  async updateLocation(userId: string, location: DriverLocation): Promise<DriverPresenceView> {
    const existing = this.rows.get(userId);
    const next: DriverPresenceView = {
      userId,
      online: existing?.online ?? true,
      rideEnabled: existing?.rideEnabled ?? true,
      foodEnabled: existing?.foodEnabled ?? true,
      lat: location.lat,
      lng: location.lng,
      locationAt: location.at,
      updatedAt: new Date(),
    };
    this.rows.set(userId, next);
    return { ...next };
  }

  async findByUserId(userId: string): Promise<DriverPresenceView | null> {
    const row = this.rows.get(userId);
    return row ? { ...row } : null;
  }

  async listOnlineNear(input: {
    service: DispatchService;
    lat: number;
    lng: number;
    radiusKm: number;
    freshSince: Date;
    limit: number;
  }): Promise<DriverPresenceView[]> {
    const box = radiusBox(input.lat, input.lng, input.radiusKm);
    return [...this.rows.values()]
      .filter(
        (row) =>
          row.online &&
          (input.service === 'RIDE' ? row.rideEnabled : row.foodEnabled) &&
          row.lat !== null &&
          row.lng !== null &&
          row.locationAt !== null &&
          row.locationAt.getTime() >= input.freshSince.getTime() &&
          row.lat >= box.minLat &&
          row.lat <= box.maxLat &&
          row.lng >= box.minLng &&
          row.lng <= box.maxLng,
      )
      .slice(0, input.limit)
      .map((row) => ({ ...row }));
  }
}
