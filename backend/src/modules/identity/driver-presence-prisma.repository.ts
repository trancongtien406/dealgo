import { resolveServiceRegionCode } from '../service-area/service-regions.js';
import type { PrismaClient } from '../../generated/prisma/client.js';
import type {
  DriverPresenceRepository,
  DriverPresenceView,
  UpsertPresenceInput,
} from './driver-presence.repository.js';

export class PrismaDriverPresenceRepository implements DriverPresenceRepository {
  constructor(private readonly db: PrismaClient) {}

  async upsert(userId: string, input: UpsertPresenceInput): Promise<DriverPresenceView> {
    const existing = await this.db.driverPresence.findUnique({ where: { userId } });
    const lat = input.lat !== undefined ? input.lat : (existing?.lat ?? null);
    const lng = input.lng !== undefined ? input.lng : (existing?.lng ?? null);
    const serviceRegionCode = resolveServiceRegionCode({ lat, lng });
    const data = {
      online: input.online,
      ...(input.lat !== undefined ? { lat: input.lat } : {}),
      ...(input.lng !== undefined ? { lng: input.lng } : {}),
      serviceRegionCode,
    };
    const row = await this.db.driverPresence.upsert({
      where: { userId },
      create: {
        userId,
        online: input.online,
        lat: input.lat ?? null,
        lng: input.lng ?? null,
        serviceRegionCode,
      },
      update: data,
    });
    return toView(row);
  }

  async findByUserId(userId: string): Promise<DriverPresenceView | null> {
    const row = await this.db.driverPresence.findUnique({ where: { userId } });
    return row ? toView(row) : null;
  }
}

function toView(row: {
  userId: string;
  online: boolean;
  lat: number | null;
  lng: number | null;
  serviceRegionCode?: string | null;
  updatedAt: Date;
}): DriverPresenceView {
  return {
    userId: row.userId,
    online: row.online,
    lat: row.lat,
    lng: row.lng,
    serviceRegionCode: row.serviceRegionCode ?? null,
    updatedAt: row.updatedAt,
  };
}
