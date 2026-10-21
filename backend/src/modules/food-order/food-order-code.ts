import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import type { PickupCodeRecord } from '../ride/ride-pickup-code.js';

/**
 * DEC-PROD-036: server-issued food order codes, same rules as the ride pickup code
 * (DEC-PROD-017): 4 random digits, constant-time compare, attempts bounded per code.
 * - DELIVERY: only the customer reads it (GET /v1/food/orders/:id while ASSIGNED/PICKED_UP);
 *   the assigned driver submits it with POST …/deliver when FOOD_DELIVERY_CODE_REQUIRED.
 * - HANDOVER: only the store owner reads it (while ASSIGNED); the assigned driver submits it
 *   with POST …/pickup when FOOD_HANDOVER_CODE_REQUIRED.
 * Codes never go to ops listings, the realtime room or the other parties.
 */
export const FOOD_ORDER_CODE_STORE = Symbol('FOOD_ORDER_CODE_STORE');

export type FoodOrderCodeKind = 'DELIVERY' | 'HANDOVER';

export interface FoodOrderCodeStore {
  /** Returns the order's code of this kind, creating it with `fresh` on first use (race-safe). */
  ensure(orderId: string, kind: FoodOrderCodeKind, fresh: string): Promise<PickupCodeRecord>;
  /** Reserves one attempt; false once `max` attempts are used up. */
  reserveAttempt(orderId: string, kind: FoodOrderCodeKind, max: number): Promise<boolean>;
  /** Gives the reserved attempt back and marks the code verified. */
  markVerified(orderId: string, kind: FoodOrderCodeKind, at: Date): Promise<void>;
}

export class MemoryFoodOrderCodeStore implements FoodOrderCodeStore {
  private readonly rows = new Map<string, PickupCodeRecord>();

  ensure(orderId: string, kind: FoodOrderCodeKind, fresh: string): Promise<PickupCodeRecord> {
    const id = `${orderId}:${kind}`;
    let row = this.rows.get(id);
    if (!row) {
      row = { code: fresh, failedAttempts: 0, verifiedAt: null };
      this.rows.set(id, row);
    }
    return Promise.resolve({ ...row });
  }

  reserveAttempt(orderId: string, kind: FoodOrderCodeKind, max: number): Promise<boolean> {
    const row = this.rows.get(`${orderId}:${kind}`);
    if (!row || row.failedAttempts >= max) {
      return Promise.resolve(false);
    }
    row.failedAttempts += 1;
    return Promise.resolve(true);
  }

  markVerified(orderId: string, kind: FoodOrderCodeKind, at: Date): Promise<void> {
    const row = this.rows.get(`${orderId}:${kind}`);
    if (row) {
      row.failedAttempts = Math.max(0, row.failedAttempts - 1);
      row.verifiedAt = at;
    }
    return Promise.resolve();
  }
}

export class PrismaFoodOrderCodeStore implements FoodOrderCodeStore {
  constructor(private readonly db: PrismaClient) {}

  async ensure(orderId: string, kind: FoodOrderCodeKind, fresh: string): Promise<PickupCodeRecord> {
    const where = { orderId_kind: { orderId, kind } };
    const existing = await this.db.foodOrderCode.findUnique({ where });
    if (existing) {
      return existing;
    }
    try {
      return await this.db.foodOrderCode.create({ data: { orderId, kind, code: fresh } });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return this.db.foodOrderCode.findUniqueOrThrow({ where });
      }
      throw error;
    }
  }

  async reserveAttempt(orderId: string, kind: FoodOrderCodeKind, max: number): Promise<boolean> {
    // Guarded increment: concurrent guesses can never exceed `max` in total.
    const { count } = await this.db.foodOrderCode.updateMany({
      where: { orderId, kind, failedAttempts: { lt: max } },
      data: { failedAttempts: { increment: 1 } },
    });
    return count === 1;
  }

  async markVerified(orderId: string, kind: FoodOrderCodeKind, at: Date): Promise<void> {
    await this.db.foodOrderCode.updateMany({
      where: { orderId, kind, failedAttempts: { gt: 0 } },
      data: { failedAttempts: { decrement: 1 }, verifiedAt: at },
    });
  }
}
