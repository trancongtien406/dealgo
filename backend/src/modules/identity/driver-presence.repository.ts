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
}
