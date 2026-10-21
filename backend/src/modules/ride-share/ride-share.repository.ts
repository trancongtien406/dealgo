import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';

export const RIDE_SHARE_REPOSITORY = Symbol('RIDE_SHARE_REPOSITORY');

export type RideShareLinkRecord = {
  id: string;
  rideId: string;
  tokenHash: string;
  createdByUserId: string;
  createdAt: Date;
  expiresAt: Date;
};

export interface RideShareRepository {
  create(input: Omit<RideShareLinkRecord, 'id' | 'createdAt'>): Promise<RideShareLinkRecord>;
  findByHash(tokenHash: string): Promise<RideShareLinkRecord | null>;
  countActive(rideId: string, now: Date): Promise<number>;
}

export class MemoryRideShareRepository implements RideShareRepository {
  private readonly rows: RideShareLinkRecord[] = [];

  async create(input: Omit<RideShareLinkRecord, 'id' | 'createdAt'>): Promise<RideShareLinkRecord> {
    const row = { ...input, id: randomUUID(), createdAt: new Date() };
    this.rows.push(row);
    return { ...row };
  }

  async findByHash(tokenHash: string): Promise<RideShareLinkRecord | null> {
    const row = this.rows.find((r) => r.tokenHash === tokenHash);
    return row ? { ...row } : null;
  }

  async countActive(rideId: string, now: Date): Promise<number> {
    return this.rows.filter((r) => r.rideId === rideId && r.expiresAt > now).length;
  }
}

export class PrismaRideShareRepository implements RideShareRepository {
  constructor(private readonly db: PrismaClient) {}

  async create(input: Omit<RideShareLinkRecord, 'id' | 'createdAt'>): Promise<RideShareLinkRecord> {
    return this.db.rideShareLink.create({ data: { id: randomUUID(), ...input } });
  }

  async findByHash(tokenHash: string): Promise<RideShareLinkRecord | null> {
    return this.db.rideShareLink.findUnique({ where: { tokenHash } });
  }

  async countActive(rideId: string, now: Date): Promise<number> {
    return this.db.rideShareLink.count({ where: { rideId, expiresAt: { gt: now } } });
  }
}
