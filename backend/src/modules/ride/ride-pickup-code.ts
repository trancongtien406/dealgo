import { randomInt, timingSafeEqual } from 'node:crypto';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';

/**
 * DEC-PROD-017: server-issued pickup code. The customer reads it from GET /v1/rides/:id; the
 * assigned driver must submit it with POST /v1/rides/:id/start. Codes are never sent to drivers,
 * ops listings or the realtime room.
 */
export const RIDE_PICKUP_CODE_STORE = Symbol('RIDE_PICKUP_CODE_STORE');
export const RIDE_PICKUP_CODE_LENGTH = 4;

export type PickupCodeRecord = { code: string; failedAttempts: number; verifiedAt: Date | null };

export interface RidePickupCodeStore {
  /** Returns the ride's code, creating it with `fresh` on first use (race-safe). */
  ensure(rideId: string, fresh: string): Promise<PickupCodeRecord>;
  /** Reserves one attempt; false once `max` attempts are used up. */
  reserveAttempt(rideId: string, max: number): Promise<boolean>;
  /** Gives the reserved attempt back and marks the code verified. */
  markVerified(rideId: string, at: Date): Promise<void>;
}

export function generatePickupCode(): string {
  return String(randomInt(0, 10 ** RIDE_PICKUP_CODE_LENGTH)).padStart(RIDE_PICKUP_CODE_LENGTH, '0');
}

export function pickupCodeMatches(expected: string, submitted: string): boolean {
  const a = Buffer.from(expected);
  const b = Buffer.from(submitted);
  return a.length === b.length && timingSafeEqual(a, b);
}

export class MemoryRidePickupCodeStore implements RidePickupCodeStore {
  private readonly rows = new Map<string, PickupCodeRecord>();

  ensure(rideId: string, fresh: string): Promise<PickupCodeRecord> {
    let row = this.rows.get(rideId);
    if (!row) {
      row = { code: fresh, failedAttempts: 0, verifiedAt: null };
      this.rows.set(rideId, row);
    }
    return Promise.resolve({ ...row });
  }

  reserveAttempt(rideId: string, max: number): Promise<boolean> {
    const row = this.rows.get(rideId);
    if (!row || row.failedAttempts >= max) {
      return Promise.resolve(false);
    }
    row.failedAttempts += 1;
    return Promise.resolve(true);
  }

  markVerified(rideId: string, at: Date): Promise<void> {
    const row = this.rows.get(rideId);
    if (row) {
      row.failedAttempts = Math.max(0, row.failedAttempts - 1);
      row.verifiedAt = at;
    }
    return Promise.resolve();
  }
}

export class PrismaRidePickupCodeStore implements RidePickupCodeStore {
  constructor(private readonly db: PrismaClient) {}

  async ensure(rideId: string, fresh: string): Promise<PickupCodeRecord> {
    const existing = await this.db.ridePickupCode.findUnique({ where: { rideId } });
    if (existing) {
      return existing;
    }
    try {
      return await this.db.ridePickupCode.create({ data: { rideId, code: fresh } });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return this.db.ridePickupCode.findUniqueOrThrow({ where: { rideId } });
      }
      throw error;
    }
  }

  async reserveAttempt(rideId: string, max: number): Promise<boolean> {
    // Guarded increment: concurrent guesses can never exceed `max` in total.
    const { count } = await this.db.ridePickupCode.updateMany({
      where: { rideId, failedAttempts: { lt: max } },
      data: { failedAttempts: { increment: 1 } },
    });
    return count === 1;
  }

  async markVerified(rideId: string, at: Date): Promise<void> {
    await this.db.ridePickupCode.updateMany({
      where: { rideId, failedAttempts: { gt: 0 } },
      data: { failedAttempts: { decrement: 1 }, verifiedAt: at },
    });
  }
}
