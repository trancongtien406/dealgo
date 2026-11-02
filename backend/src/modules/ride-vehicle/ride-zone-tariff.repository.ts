import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';

/** Per-zone override of one class's perKm / minFare (owner t50u). No row = global class tariff. */
export type RideZoneTariff = {
  id: string;
  regionCode: string;
  vehicleClassCode: string;
  perKmVnd: number;
  minFareVnd: number;
  version: number;
  updatedByUserId: string | null;
  updatedAt: Date;
};

/** Pricing locked onto a ride at booking; later admin edits never change it. */
export type RidePricingSnapshot = {
  rideId: string;
  regionCode: string | null;
  tariffSource: 'ZONE' | 'DEFAULT';
  zoneTariffId: string | null;
  tariffVersion: number;
  perKmVnd: number;
  minFareVnd: number;
  bidFloorPercent: number;
  bidCeilingPercent: number;
};

export type ZoneTariffAudit = {
  action: 'RIDE_ZONE_TARIFF_UPSERT' | 'RIDE_ZONE_TARIFF_DELETE';
  reason: string;
  changes: Record<string, { from: unknown; to: unknown }>;
};

export interface RideZoneTariffRepository {
  list(): Promise<RideZoneTariff[]>;
  upsert(
    input: { regionCode: string; vehicleClassCode: string; perKmVnd: number; minFareVnd: number },
    actorUserId: string,
    audit: ZoneTariffAudit,
  ): Promise<RideZoneTariff>;
  remove(regionCode: string, vehicleClassCode: string, actorUserId: string, audit: ZoneTariffAudit): Promise<boolean>;
  saveSnapshot(snapshot: RidePricingSnapshot): Promise<void>;
  findSnapshot(rideId: string): Promise<RidePricingSnapshot | null>;
  findSnapshots(rideIds: readonly string[]): Promise<Map<string, RidePricingSnapshot>>;
}

const key = (regionCode: string, vehicleClassCode: string) => `${regionCode}:${vehicleClassCode}`;

export class MemoryRideZoneTariffRepository implements RideZoneTariffRepository {
  private readonly rows = new Map<string, RideZoneTariff>();
  private readonly snapshots = new Map<string, RidePricingSnapshot>();
  readonly audits: Array<{ actorUserId: string; entityId: string } & ZoneTariffAudit> = [];

  list(): Promise<RideZoneTariff[]> {
    return Promise.resolve(
      [...this.rows.values()]
        .sort((a, b) => a.regionCode.localeCompare(b.regionCode) || a.vehicleClassCode.localeCompare(b.vehicleClassCode))
        .map((row) => ({ ...row })),
    );
  }

  upsert(
    input: { regionCode: string; vehicleClassCode: string; perKmVnd: number; minFareVnd: number },
    actorUserId: string,
    audit: ZoneTariffAudit,
  ): Promise<RideZoneTariff> {
    const k = key(input.regionCode, input.vehicleClassCode);
    const current = this.rows.get(k);
    const next: RideZoneTariff = {
      id: current?.id ?? randomUUID(),
      ...input,
      version: (current?.version ?? 0) + 1,
      updatedByUserId: actorUserId,
      updatedAt: new Date(),
    };
    this.rows.set(k, next);
    this.audits.push({ actorUserId, entityId: next.id, ...audit });
    return Promise.resolve({ ...next });
  }

  remove(regionCode: string, vehicleClassCode: string, actorUserId: string, audit: ZoneTariffAudit): Promise<boolean> {
    const current = this.rows.get(key(regionCode, vehicleClassCode));
    if (!current) return Promise.resolve(false);
    this.rows.delete(key(regionCode, vehicleClassCode));
    this.audits.push({ actorUserId, entityId: current.id, ...audit });
    return Promise.resolve(true);
  }

  saveSnapshot(snapshot: RidePricingSnapshot): Promise<void> {
    if (!this.snapshots.has(snapshot.rideId)) this.snapshots.set(snapshot.rideId, { ...snapshot });
    return Promise.resolve();
  }

  findSnapshot(rideId: string): Promise<RidePricingSnapshot | null> {
    const found = this.snapshots.get(rideId);
    return Promise.resolve(found ? { ...found } : null);
  }

  findSnapshots(rideIds: readonly string[]): Promise<Map<string, RidePricingSnapshot>> {
    const found = new Map<string, RidePricingSnapshot>();
    for (const rideId of rideIds) {
      const snapshot = this.snapshots.get(rideId);
      if (snapshot) found.set(rideId, { ...snapshot });
    }
    return Promise.resolve(found);
  }
}

type ZoneRow = {
  id: string;
  regionCode: string;
  vehicleClassCode: string;
  perKmVnd: number;
  minFareVnd: number;
  version: number;
  updatedByUserId: string | null;
  updatedAt: Date;
};

const fromRow = (row: ZoneRow): RideZoneTariff => ({
  id: row.id,
  regionCode: row.regionCode,
  vehicleClassCode: row.vehicleClassCode,
  perKmVnd: row.perKmVnd,
  minFareVnd: row.minFareVnd,
  version: row.version,
  updatedByUserId: row.updatedByUserId,
  updatedAt: row.updatedAt,
});

export class PrismaRideZoneTariffRepository implements RideZoneTariffRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(): Promise<RideZoneTariff[]> {
    const rows = await this.db.rideZoneTariff.findMany({
      orderBy: [{ regionCode: 'asc' }, { vehicleClassCode: 'asc' }],
    });
    return rows.map(fromRow);
  }

  async upsert(
    input: { regionCode: string; vehicleClassCode: string; perKmVnd: number; minFareVnd: number },
    actorUserId: string,
    audit: ZoneTariffAudit,
  ): Promise<RideZoneTariff> {
    const row = await this.db.$transaction(async (tx) => {
      const saved = await tx.rideZoneTariff.upsert({
        where: {
          regionCode_vehicleClassCode: { regionCode: input.regionCode, vehicleClassCode: input.vehicleClassCode },
        },
        create: { id: randomUUID(), ...input, version: 1, updatedByUserId: actorUserId },
        update: {
          perKmVnd: input.perKmVnd,
          minFareVnd: input.minFareVnd,
          version: { increment: 1 },
          updatedByUserId: actorUserId,
        },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId,
          action: audit.action,
          entityType: 'RIDE_ZONE_TARIFF',
          entityId: saved.id,
          reason: audit.reason.slice(0, 500),
          metadata: { regionCode: input.regionCode, vehicleClassCode: input.vehicleClassCode, changes: audit.changes } as never,
        },
      });
      return saved;
    });
    return fromRow(row);
  }

  async remove(regionCode: string, vehicleClassCode: string, actorUserId: string, audit: ZoneTariffAudit): Promise<boolean> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.rideZoneTariff.findUnique({
        where: { regionCode_vehicleClassCode: { regionCode, vehicleClassCode } },
      });
      if (!current) return false;
      await tx.rideZoneTariff.delete({ where: { id: current.id } });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId,
          action: audit.action,
          entityType: 'RIDE_ZONE_TARIFF',
          entityId: current.id,
          reason: audit.reason.slice(0, 500),
          metadata: { regionCode, vehicleClassCode, changes: audit.changes } as never,
        },
      });
      return true;
    });
  }

  async saveSnapshot(snapshot: RidePricingSnapshot): Promise<void> {
    await this.db.ridePricingSnapshot.upsert({
      where: { rideId: snapshot.rideId },
      create: snapshot,
      update: {},
    });
  }

  async findSnapshot(rideId: string): Promise<RidePricingSnapshot | null> {
    const row = await this.db.ridePricingSnapshot.findUnique({ where: { rideId } });
    return row ? snapshotFromRow(row) : null;
  }

  async findSnapshots(rideIds: readonly string[]): Promise<Map<string, RidePricingSnapshot>> {
    const found = new Map<string, RidePricingSnapshot>();
    if (rideIds.length === 0) return found;
    const rows = await this.db.ridePricingSnapshot.findMany({ where: { rideId: { in: [...rideIds] } } });
    for (const row of rows) found.set(row.rideId, snapshotFromRow(row));
    return found;
  }
}

function snapshotFromRow(row: {
  rideId: string;
  regionCode: string | null;
  tariffSource: string;
  zoneTariffId: string | null;
  tariffVersion: number;
  perKmVnd: number;
  minFareVnd: number;
  bidFloorPercent: number;
  bidCeilingPercent: number;
}): RidePricingSnapshot {
  return {
    rideId: row.rideId,
    regionCode: row.regionCode,
    tariffSource: row.tariffSource === 'ZONE' ? 'ZONE' : 'DEFAULT',
    zoneTariffId: row.zoneTariffId,
    tariffVersion: row.tariffVersion,
    perKmVnd: row.perKmVnd,
    minFareVnd: row.minFareVnd,
    bidFloorPercent: row.bidFloorPercent,
    bidCeilingPercent: row.bidCeilingPercent,
  };
}
