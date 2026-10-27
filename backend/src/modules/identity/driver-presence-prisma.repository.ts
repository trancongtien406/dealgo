import { resolveServiceRegionCode } from '../service-area/service-regions.js';
import type { PrismaClient } from '../../generated/prisma/client.js';
import { radiusBox, type DispatchService } from './driver-presence.repository.js';
import type {
  DriverLocation,
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
      ...(input.rideEnabled !== undefined ? { rideEnabled: input.rideEnabled } : {}),
      ...(input.foodEnabled !== undefined ? { foodEnabled: input.foodEnabled } : {}),
      ...(input.lat !== undefined ? { lat: input.lat } : {}),
      ...(input.lng !== undefined ? { lng: input.lng } : {}),
      ...(input.lat !== undefined && input.lng !== undefined ? { locationAt: new Date() } : {}),
      serviceRegionCode,
    };
    const row = await this.db.driverPresence.upsert({
      where: { userId },
      create: {
        userId,
        online: input.online,
        rideEnabled: input.rideEnabled ?? true,
        foodEnabled: input.foodEnabled ?? true,
        lat: input.lat ?? null,
        lng: input.lng ?? null,
        locationAt: input.lat !== undefined && input.lng !== undefined ? new Date() : null,
        serviceRegionCode,
      },
      update: data,
    });
    return toView(row);
  }

  async updateLocation(userId: string, location: DriverLocation): Promise<DriverPresenceView> {
    const serviceRegionCode = resolveServiceRegionCode({ lat: location.lat, lng: location.lng });
    const row = await this.db.driverPresence.upsert({
      where: { userId },
      create: {
        userId,
        online: true,
        lat: location.lat,
        lng: location.lng,
        locationAt: location.at,
        serviceRegionCode,
      },
      update: {
        lat: location.lat,
        lng: location.lng,
        locationAt: location.at,
        serviceRegionCode,
      },
    });
    return toView(row);
  }

  async findByUserId(userId: string): Promise<DriverPresenceView | null> {
    const row = await this.db.driverPresence.findUnique({ where: { userId } });
    return row ? toView(row) : null;
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
    const rows = await this.db.driverPresence.findMany({
      where: {
        online: true,
        ...(input.service === 'RIDE' ? { rideEnabled: true } : { foodEnabled: true }),
        locationAt: { gte: input.freshSince },
        lat: { gte: box.minLat, lte: box.maxLat },
        lng: { gte: box.minLng, lte: box.maxLng },
      },
      orderBy: { locationAt: 'desc' },
      take: input.limit,
    });
    return rows.map(toView);
  }
}

function toView(row: {
  userId: string;
  online: boolean;
  rideEnabled: boolean;
  foodEnabled: boolean;
  lat: number | null;
  lng: number | null;
  locationAt: Date | null;
  serviceRegionCode?: string | null;
  updatedAt: Date;
}): DriverPresenceView {
  return {
    userId: row.userId,
    online: row.online,
    rideEnabled: row.rideEnabled,
    foodEnabled: row.foodEnabled,
    lat: row.lat,
    lng: row.lng,
    locationAt: row.locationAt,
    serviceRegionCode: row.serviceRegionCode ?? null,
    updatedAt: row.updatedAt,
  };
}
