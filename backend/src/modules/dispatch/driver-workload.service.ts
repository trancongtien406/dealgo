import { HttpException, Injectable, Optional } from '@nestjs/common';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';

/** Ride (incl. parcel) states where the assigned driver is on a job. */
export const ACTIVE_RIDE_STATUSES = ['ASSIGNED', 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED', 'IN_TRIP'] as const;
/** Food states where the assigned driver is on a job (PREPARING = early-assigned). */
export const ACTIVE_FOOD_STATUSES = ['PREPARING', 'ASSIGNED', 'PICKED_UP'] as const;

/** Minimal read surface so tests can stub the counts without a database. */
export interface DriverWorkloadSource {
  activeJobCounts(driverIds: readonly string[]): Promise<Map<string, number>>;
}

/**
 * t71u — "busy driver" gate (Grab/inDrive: a driver on a trip gets no new requests until it
 * ends). A driver whose active rides + parcel + food jobs reach MAX_CONCURRENT_JOBS_PER_DRIVER
 * (default 1) is left out of request fan-out, re-push, open/ready feeds and cannot send offers.
 * Assignment itself is still serialized + re-checked in the ride select / food claim tx.
 */
@Injectable()
export class DriverWorkloadService {
  private source: DriverWorkloadSource | null = null;

  constructor(
    @Optional() private readonly prisma?: PrismaService,
    @Optional() private readonly settings?: PlatformSettingsService,
  ) {}

  /** Test hook / alternative source (memory persistence has no DB). */
  useSource(source: DriverWorkloadSource | null): void {
    this.source = source;
  }

  async maxJobs(): Promise<number> {
    const raw = await this.settings?.getNumber('MAX_CONCURRENT_JOBS_PER_DRIVER').catch(() => undefined);
    return typeof raw === 'number' && Number.isFinite(raw) && raw >= 1 ? Math.floor(raw) : 1;
  }

  async activeJobCounts(driverIds: readonly string[]): Promise<Map<string, number>> {
    const ids = [...new Set(driverIds)];
    const counts = new Map<string, number>(ids.map((id) => [id, 0]));
    if (ids.length === 0) return counts;
    if (this.source) return this.source.activeJobCounts(ids);
    const db = this.prisma?.db();
    if (!db) return counts;
    const [rides, food] = await Promise.all([
      db.ride.groupBy({
        by: ['assignedDriverId'],
        where: { assignedDriverId: { in: ids }, status: { in: [...ACTIVE_RIDE_STATUSES] } },
        _count: { _all: true },
      }),
      db.foodOrder.groupBy({
        by: ['assignedDriverId'],
        where: { assignedDriverId: { in: ids }, status: { in: [...ACTIVE_FOOD_STATUSES] } },
        _count: { _all: true },
      }),
    ]);
    for (const row of [...rides, ...food]) {
      if (!row.assignedDriverId) continue;
      counts.set(row.assignedDriverId, (counts.get(row.assignedDriverId) ?? 0) + row._count._all);
    }
    return counts;
  }

  /** Drivers from `driverIds` that may still receive a new job (order kept). */
  async availableOnly(driverIds: readonly string[]): Promise<string[]> {
    if (driverIds.length === 0) return [];
    const [counts, max] = await Promise.all([this.activeJobCounts(driverIds), this.maxJobs()]);
    return driverIds.filter((id) => (counts.get(id) ?? 0) < max);
  }

  async isBusy(driverId: string): Promise<boolean> {
    return (await this.availableOnly([driverId])).length === 0;
  }

  /** 409 DRIVER_AT_CAPACITY when the driver is on a job (offer submission). */
  async assertAvailable(driverId: string): Promise<void> {
    if (await this.isBusy(driverId)) {
      throw new HttpException(
        { message: 'Finish your current trip before taking a new one', errorCode: 'DRIVER_AT_CAPACITY' },
        409,
      );
    }
  }

  /**
   * Once a driver is assigned, their PENDING offers on other negotiating rides are withdrawn.
   * Returns the affected ride ids so callers can refresh those customers' offer lists.
   */
  async withdrawOtherOffers(driverId: string, exceptRideId: string): Promise<string[]> {
    const db = this.prisma?.db();
    if (!db) return [];
    const pending = await db.rideOffer.findMany({
      where: { driverId, status: 'PENDING', rideId: { not: exceptRideId }, ride: { status: 'NEGOTIATING' } },
      select: { id: true, rideId: true },
    });
    if (pending.length === 0) return [];
    await db.rideOffer.updateMany({
      where: { id: { in: pending.map((o) => o.id) }, status: 'PENDING' },
      data: { status: 'WITHDRAWN' },
    });
    return [...new Set(pending.map((o) => o.rideId))];
  }
}
