export type DriverPresenceView = {
  userId: string;
  online: boolean;
  lat: number | null;
  lng: number | null;
  serviceRegionCode?: string | null;
  updatedAt: Date;
};

export type UpsertPresenceInput = {
  online: boolean;
  lat?: number;
  lng?: number;
};

export interface DriverPresenceRepository {
  upsert(userId: string, input: UpsertPresenceInput): Promise<DriverPresenceView>;
  findByUserId(userId: string): Promise<DriverPresenceView | null>;
}

export class MemoryDriverPresenceRepository implements DriverPresenceRepository {
  private readonly rows = new Map<string, DriverPresenceView>();

  async upsert(userId: string, input: UpsertPresenceInput): Promise<DriverPresenceView> {
    const existing = this.rows.get(userId);
    const next: DriverPresenceView = {
      userId,
      online: input.online,
      lat: input.lat !== undefined ? input.lat : (existing?.lat ?? null),
      lng: input.lng !== undefined ? input.lng : (existing?.lng ?? null),
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
