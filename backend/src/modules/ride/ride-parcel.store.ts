import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { writeStatusOutbox } from '../communication/outbox/outbox.write.js';
import type { StoredDocumentRef } from '../../platform/storage/document-store.service.js';
import type { ParcelSizeCode } from '../../platform/settings/parcel-size-classes.js';

/**
 * DEC-PROD-071 (DRAFT): goods carried by a ride (1:1). The lifecycle stays on the ride:
 * NEGOTIATING..ASSIGNED..DRIVER_ARRIVED (at sender) → IN_TRIP (in transit) → COMPLETED.
 * `outcome` says how the job ended (DELIVERED or RETURNED after RETURNING).
 */
export const RIDE_PARCEL_STORE = Symbol('RIDE_PARCEL_STORE');

export type ParcelPayerName = 'SENDER' | 'RECIPIENT';
export type ParcelOutcomeName = 'PENDING' | 'DELIVERED' | 'RETURNING' | 'RETURNED';
export type ParcelPhotoKind = 'item' | 'pickup' | 'delivery' | 'return';

export type ParcelRecord = {
  rideId: string;
  senderName: string;
  senderPhone: string;
  recipientName: string;
  recipientPhone: string;
  sizeClass: ParcelSizeCode;
  weightKg: number | null;
  note: string | null;
  payer: ParcelPayerName;
  surchargeVnd: number;
  /** DEC-PROD-071: PARCEL_SERVICE_FEE_VND snapshot folded into the reference fare. */
  serviceFeeVnd: number;
  /** DEC-PROD-071: PARCEL_RETURN_FEE_VND snapshot, charged on RETURNED. */
  returnFeeVnd: number;
  itemPhoto: StoredDocumentRef | null;
  recipientCode: string | null;
  recipientCodeFails: number;
  pickupPhoto: StoredDocumentRef | null;
  pickedUpAt: Date | null;
  deliveryPhoto: StoredDocumentRef | null;
  deliveredAt: Date | null;
  outcome: ParcelOutcomeName;
  failReason: string | null;
  failNote: string | null;
  failedAt: Date | null;
  returnPhoto: StoredDocumentRef | null;
  returnedAt: Date | null;
  createdAt: Date;
};

export type NewParcel = Pick<
  ParcelRecord,
  | 'rideId'
  | 'senderName'
  | 'senderPhone'
  | 'recipientName'
  | 'recipientPhone'
  | 'sizeClass'
  | 'weightKg'
  | 'note'
  | 'payer'
  | 'surchargeVnd'
  | 'serviceFeeVnd'
  | 'returnFeeVnd'
  | 'itemPhoto'
  | 'recipientCode'
>;

export type ParcelPatch = Partial<
  Pick<
    ParcelRecord,
    | 'pickupPhoto'
    | 'pickedUpAt'
    | 'deliveryPhoto'
    | 'deliveredAt'
    | 'outcome'
    | 'failReason'
    | 'failNote'
    | 'failedAt'
    | 'returnPhoto'
    | 'returnedAt'
  >
>;

/** Realtime hint written with the patch (Ride status room; no polling). */
export type ParcelOutboxHint = { status: string; suffix: string; payload: Record<string, unknown> };

export type OpsParcelRow = ParcelRecord & {
  ride: {
    status: string;
    customerId: string;
    assignedDriverId: string | null;
    vehicleClassCode: string;
    pickupLabel: string;
    dropoffLabel: string;
    agreedFareVnd: number | null;
    offeredFareVnd: number;
    serviceRegionCode: string | null;
  } | null;
};

export type OpsParcelQuery = { page: number; limit: number; outcome?: ParcelOutcomeName; q?: string };

export interface RideParcelStore {
  /**
   * Inserts once per ride; an idempotent replay returns the first row. `tx` = the ride
   * repository's transaction handle so the row commits with the ride.
   */
  create(input: NewParcel, tx?: unknown): Promise<ParcelRecord>;
  find(rideId: string): Promise<ParcelRecord | null>;
  /** Parcel rows among the given ride ids (dispatch tags open/push lists). */
  findMany(rideIds: readonly string[]): Promise<Map<string, ParcelRecord>>;
  /** Conditional update: applied only when the current outcome is one of `fromOutcomes`. */
  update(
    rideId: string,
    fromOutcomes: readonly ParcelOutcomeName[],
    patch: ParcelPatch,
    hint?: ParcelOutboxHint,
  ): Promise<ParcelRecord | null>;
  /** Reserves one recipient-code attempt; false once `max` attempts are used. */
  reserveCodeAttempt(rideId: string, max: number): Promise<boolean>;
  listForOps(query: OpsParcelQuery): Promise<{ items: OpsParcelRow[]; total: number }>;
}

export class MemoryRideParcelStore implements RideParcelStore {
  private readonly rows = new Map<string, ParcelRecord>();

  async create(input: NewParcel): Promise<ParcelRecord> {
    const existing = this.rows.get(input.rideId);
    if (existing) return { ...existing };
    const row: ParcelRecord = {
      ...input,
      recipientCodeFails: 0,
      pickupPhoto: null,
      pickedUpAt: null,
      deliveryPhoto: null,
      deliveredAt: null,
      outcome: 'PENDING',
      failReason: null,
      failNote: null,
      failedAt: null,
      returnPhoto: null,
      returnedAt: null,
      createdAt: new Date(),
    };
    this.rows.set(input.rideId, row);
    return { ...row };
  }

  async find(rideId: string): Promise<ParcelRecord | null> {
    const row = this.rows.get(rideId);
    return row ? { ...row } : null;
  }

  async findMany(rideIds: readonly string[]): Promise<Map<string, ParcelRecord>> {
    const out = new Map<string, ParcelRecord>();
    for (const id of rideIds) {
      const row = this.rows.get(id);
      if (row) out.set(id, { ...row });
    }
    return out;
  }

  async update(
    rideId: string,
    fromOutcomes: readonly ParcelOutcomeName[],
    patch: ParcelPatch,
  ): Promise<ParcelRecord | null> {
    const row = this.rows.get(rideId);
    if (!row || !fromOutcomes.includes(row.outcome)) return null;
    Object.assign(row, patch);
    return { ...row };
  }

  async reserveCodeAttempt(rideId: string, max: number): Promise<boolean> {
    const row = this.rows.get(rideId);
    if (!row || row.recipientCodeFails >= max) return false;
    row.recipientCodeFails += 1;
    return true;
  }

  async listForOps(query: OpsParcelQuery): Promise<{ items: OpsParcelRow[]; total: number }> {
    const all = [...this.rows.values()]
      .filter((row) => !query.outcome || row.outcome === query.outcome)
      .filter((row) => !query.q || matchesQ(row, query.q))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    const start = (query.page - 1) * query.limit;
    return {
      items: all.slice(start, start + query.limit).map((row) => ({ ...row, ride: null })),
      total: all.length,
    };
  }
}

function matchesQ(row: ParcelRecord, q: string): boolean {
  const needle = q.trim().toLowerCase();
  return [row.rideId, row.senderPhone, row.recipientPhone, row.senderName, row.recipientName].some((v) =>
    v.toLowerCase().includes(needle),
  );
}

type ParcelRow = Prisma.RideParcelGetPayload<object>;

function photo(value: Prisma.JsonValue | null): StoredDocumentRef | null {
  return value && typeof value === 'object' && !Array.isArray(value) && typeof (value as { key?: unknown }).key === 'string'
    ? (value as unknown as StoredDocumentRef)
    : null;
}

function fromRow(row: ParcelRow): ParcelRecord {
  return {
    rideId: row.rideId,
    senderName: row.senderName,
    senderPhone: row.senderPhone,
    recipientName: row.recipientName,
    recipientPhone: row.recipientPhone,
    sizeClass: row.sizeClass as ParcelSizeCode,
    weightKg: row.weightKg,
    note: row.note,
    payer: row.payer,
    surchargeVnd: row.surchargeVnd,
    serviceFeeVnd: row.serviceFeeVnd,
    returnFeeVnd: row.returnFeeVnd,
    itemPhoto: photo(row.itemPhoto),
    recipientCode: row.recipientCode,
    recipientCodeFails: row.recipientCodeFails,
    pickupPhoto: photo(row.pickupPhoto),
    pickedUpAt: row.pickedUpAt,
    deliveryPhoto: photo(row.deliveryPhoto),
    deliveredAt: row.deliveredAt,
    outcome: row.outcome,
    failReason: row.failReason,
    failNote: row.failNote,
    failedAt: row.failedAt,
    returnPhoto: photo(row.returnPhoto),
    returnedAt: row.returnedAt,
    createdAt: row.createdAt,
  };
}

function json(ref: StoredDocumentRef | null | undefined): Prisma.InputJsonValue | typeof Prisma.DbNull | undefined {
  if (ref === undefined) return undefined;
  return ref === null ? Prisma.DbNull : (ref as unknown as Prisma.InputJsonValue);
}

export class PrismaRideParcelStore implements RideParcelStore {
  constructor(private readonly db: PrismaClient) {}

  async create(input: NewParcel, tx?: unknown): Promise<ParcelRecord> {
    if (tx) {
      // Inside the ride create transaction: no P2002 recovery (it would abort the tx).
      const db = tx as Prisma.TransactionClient;
      const found = await db.rideParcel.findUnique({ where: { rideId: input.rideId } });
      if (found) return fromRow(found);
      return fromRow(await db.rideParcel.create({ data: { ...input, itemPhoto: json(input.itemPhoto) } }));
    }
    const existing = await this.db.rideParcel.findUnique({ where: { rideId: input.rideId } });
    if (existing) return fromRow(existing);
    try {
      const row = await this.db.rideParcel.create({
        data: {
          ...input,
          itemPhoto: json(input.itemPhoto),
        },
      });
      return fromRow(row);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return fromRow(await this.db.rideParcel.findUniqueOrThrow({ where: { rideId: input.rideId } }));
      }
      throw error;
    }
  }

  async find(rideId: string): Promise<ParcelRecord | null> {
    const row = await this.db.rideParcel.findUnique({ where: { rideId } });
    return row ? fromRow(row) : null;
  }

  async findMany(rideIds: readonly string[]): Promise<Map<string, ParcelRecord>> {
    if (rideIds.length === 0) return new Map();
    const rows = await this.db.rideParcel.findMany({ where: { rideId: { in: [...rideIds] } } });
    return new Map(rows.map((row) => [row.rideId, fromRow(row)]));
  }

  async update(
    rideId: string,
    fromOutcomes: readonly ParcelOutcomeName[],
    patch: ParcelPatch,
    hint?: ParcelOutboxHint,
  ): Promise<ParcelRecord | null> {
    const data: Prisma.RideParcelUpdateManyMutationInput = {
      ...(patch.pickedUpAt !== undefined ? { pickedUpAt: patch.pickedUpAt } : {}),
      ...(patch.deliveredAt !== undefined ? { deliveredAt: patch.deliveredAt } : {}),
      ...(patch.outcome !== undefined ? { outcome: patch.outcome } : {}),
      ...(patch.failReason !== undefined ? { failReason: patch.failReason } : {}),
      ...(patch.failNote !== undefined ? { failNote: patch.failNote } : {}),
      ...(patch.failedAt !== undefined ? { failedAt: patch.failedAt } : {}),
      ...(patch.returnedAt !== undefined ? { returnedAt: patch.returnedAt } : {}),
      ...(patch.pickupPhoto !== undefined ? { pickupPhoto: json(patch.pickupPhoto) } : {}),
      ...(patch.deliveryPhoto !== undefined ? { deliveryPhoto: json(patch.deliveryPhoto) } : {}),
      ...(patch.returnPhoto !== undefined ? { returnPhoto: json(patch.returnPhoto) } : {}),
    };
    return this.db.$transaction(async (tx) => {
      const result = await tx.rideParcel.updateMany({
        where: { rideId, outcome: { in: [...fromOutcomes] } },
        data,
      });
      if (result.count === 0) return null;
      if (hint) {
        await writeStatusOutbox(tx, {
          aggregateType: 'Ride',
          aggregateId: rideId,
          status: hint.status,
          payload: hint.payload,
          eventKeySuffix: hint.suffix,
        });
      }
      return fromRow(await tx.rideParcel.findUniqueOrThrow({ where: { rideId } }));
    });
  }

  async reserveCodeAttempt(rideId: string, max: number): Promise<boolean> {
    const result = await this.db.rideParcel.updateMany({
      where: { rideId, recipientCodeFails: { lt: max } },
      data: { recipientCodeFails: { increment: 1 } },
    });
    return result.count === 1;
  }

  async listForOps(query: OpsParcelQuery): Promise<{ items: OpsParcelRow[]; total: number }> {
    const q = query.q?.trim();
    const where: Prisma.RideParcelWhereInput = {
      ...(query.outcome ? { outcome: query.outcome } : {}),
      ...(q
        ? {
            OR: [
              { senderPhone: { contains: q } },
              { recipientPhone: { contains: q } },
              { senderName: { contains: q, mode: 'insensitive' } },
              { recipientName: { contains: q, mode: 'insensitive' } },
              ...(/^[0-9a-f-]{36}$/i.test(q) ? [{ rideId: q }] : []),
            ],
          }
        : {}),
    };
    const [rows, total] = await Promise.all([
      this.db.rideParcel.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (query.page - 1) * query.limit,
        take: query.limit,
        include: {
          ride: {
            select: {
              status: true,
              customerId: true,
              assignedDriverId: true,
              vehicleClassCode: true,
              pickupLabel: true,
              dropoffLabel: true,
              agreedFareVnd: true,
              offeredFareVnd: true,
              serviceRegionCode: true,
            },
          },
        },
      }),
      this.db.rideParcel.count({ where }),
    ]);
    return { items: rows.map((row) => ({ ...fromRow(row), ride: row.ride })), total };
  }
}
