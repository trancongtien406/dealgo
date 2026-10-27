import { createHash, randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';
import type { RideVehicleClass } from './ride-vehicle-class.js';

/** Field-level change recorded in the ops audit log: `{ field: { from, to } }`. */
export type VehicleClassChanges = Record<string, { from: unknown; to: unknown }>;

export type VehicleClassAudit = {
  reason: string;
  changes: VehicleClassChanges;
};

/**
 * Stable UUID (v5-style, SHA-1) for a vehicle class code. `ops_audit_logs.entityId` is a UUID
 * column while classes are keyed by code, so every edit of one class shares this id.
 */
export function rideVehicleClassAuditId(code: string): string {
  const hex = createHash('sha1').update(`dealgo:ride-vehicle-class:${code}`).digest('hex');
  const variant = ((parseInt(hex.slice(16, 18), 16) & 0x3f) | 0x80).toString(16).padStart(2, '0');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-5${hex.slice(13, 16)}-${variant}${hex.slice(18, 20)}-${hex.slice(20, 32)}`;
}

export interface RideVehicleClassRepository {
  count(): Promise<number>;
  list(): Promise<RideVehicleClass[]>;
  insertDefaults(rows: RideVehicleClass[]): Promise<void>;
  update(
    code: string,
    patch: Partial<
      Pick<
        RideVehicleClass,
        | 'name'
        | 'seats'
        | 'enabled'
        | 'baseFareVnd'
        | 'perKmVnd'
        | 'perMinuteVnd'
        | 'minFareVnd'
        | 'maxFareVnd'
        | 'assumedSpeedKmh'
        | 'imageUrl'
      >
    >,
    updatedByUserId: string,
    audit?: VehicleClassAudit,
  ): Promise<RideVehicleClass | null>;
}

type VehicleClassPatch = Parameters<RideVehicleClassRepository['update']>[1];

function clone(row: RideVehicleClass): RideVehicleClass {
  return { ...row };
}

export class MemoryRideVehicleClassRepository implements RideVehicleClassRepository {
  private readonly rows = new Map<string, RideVehicleClass>();
  /** Audit entries written alongside updates (in-memory mode only). */
  readonly audits: Array<{ code: string; actorUserId: string } & VehicleClassAudit> = [];

  count(): Promise<number> {
    return Promise.resolve(this.rows.size);
  }

  list(): Promise<RideVehicleClass[]> {
    return Promise.resolve(
      [...this.rows.values()]
        .sort((left, right) => left.sortOrder - right.sortOrder || left.code.localeCompare(right.code))
        .map(clone),
    );
  }

  insertDefaults(rows: RideVehicleClass[]): Promise<void> {
    if (this.rows.size > 0) {
      return Promise.resolve();
    }
    for (const row of rows) {
      this.rows.set(row.code, clone(row));
    }
    return Promise.resolve();
  }

  update(
    code: string,
    patch: VehicleClassPatch,
    updatedByUserId: string,
    audit?: VehicleClassAudit,
  ): Promise<RideVehicleClass | null> {
    const current = this.rows.get(code);
    if (!current) {
      return Promise.resolve(null);
    }
    const next = { ...current, ...patch, updatedByUserId };
    this.rows.set(code, next);
    if (audit) {
      this.audits.push({ code, actorUserId: updatedByUserId, ...audit });
    }
    return Promise.resolve(clone(next));
  }
}

function fromRecord(row: {
  code: string;
  name: string;
  seats: number;
  enabled: boolean;
  baseFareVnd: number;
  perKmVnd: number;
  perMinuteVnd: number;
  minFareVnd: number;
  maxFareVnd: number;
  assumedSpeedKmh: number;
  sortOrder: number;
  imageUrl: string | null;
  updatedByUserId: string | null;
}): RideVehicleClass {
  return {
    code: row.code,
    name: row.name,
    seats: row.seats,
    enabled: row.enabled,
    baseFareVnd: row.baseFareVnd,
    perKmVnd: row.perKmVnd,
    perMinuteVnd: row.perMinuteVnd,
    minFareVnd: row.minFareVnd,
    maxFareVnd: row.maxFareVnd,
    assumedSpeedKmh: row.assumedSpeedKmh,
    sortOrder: row.sortOrder,
    imageUrl: row.imageUrl,
    updatedByUserId: row.updatedByUserId,
  };
}

export class PrismaRideVehicleClassRepository implements RideVehicleClassRepository {
  constructor(private readonly db: PrismaClient) {}

  async count(): Promise<number> {
    return this.db.rideVehicleClass.count();
  }

  async list(): Promise<RideVehicleClass[]> {
    const rows = await this.db.rideVehicleClass.findMany({
      orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
    });
    return rows.map(fromRecord);
  }

  async insertDefaults(rows: RideVehicleClass[]): Promise<void> {
    await this.db.rideVehicleClass.createMany({
      data: rows.map((row) => ({
        code: row.code,
        name: row.name,
        seats: row.seats,
        enabled: row.enabled,
        baseFareVnd: row.baseFareVnd,
        perKmVnd: row.perKmVnd,
        perMinuteVnd: row.perMinuteVnd,
        minFareVnd: row.minFareVnd,
        maxFareVnd: row.maxFareVnd,
        assumedSpeedKmh: row.assumedSpeedKmh,
        sortOrder: row.sortOrder,
      })),
      skipDuplicates: true,
    });
  }

  async update(
    code: string,
    patch: VehicleClassPatch,
    updatedByUserId: string,
    audit?: VehicleClassAudit,
  ): Promise<RideVehicleClass | null> {
    const existing = await this.db.rideVehicleClass.findUnique({ where: { code } });
    if (!existing) {
      return null;
    }
    const row = await this.db.$transaction(async (tx) => {
      const updated = await tx.rideVehicleClass.update({
        where: { code },
        data: { ...patch, updatedByUserId },
      });
      if (audit) {
        await tx.opsAuditLog.create({
          data: {
            id: randomUUID(),
            actorUserId: updatedByUserId,
            action: 'RIDE_VEHICLE_CLASS_UPDATE',
            entityType: 'RIDE_VEHICLE_CLASS',
            entityId: rideVehicleClassAuditId(code),
            reason: audit.reason.slice(0, 500),
            metadata: { code, changes: audit.changes } as never,
          },
        });
      }
      return updated;
    });
    return fromRecord(row);
  }
}
