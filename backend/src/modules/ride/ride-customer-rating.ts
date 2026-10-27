import { randomUUID } from 'node:crypto';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';

export const RIDE_CUSTOMER_RATING_STORE = Symbol('RIDE_CUSTOMER_RATING_STORE');

/** Tags a driver may attach when rating a customer. */
export const CUSTOMER_RATING_TAGS = [
  'ON_TIME',
  'POLITE',
  'CLEAR_PICKUP',
  'LATE',
  'RUDE',
  'WRONG_PICKUP',
] as const;
export type CustomerRatingTag = (typeof CUSTOMER_RATING_TAGS)[number];

export type CustomerRating = {
  id: string;
  rideId: string;
  customerId: string;
  driverId: string;
  stars: number;
  tags: string[];
  comment: string | null;
  createdAt: Date;
};

/** What a driver sees about a customer before/while taking the ride. */
export type CustomerRatingSummary = { average: number | null; count: number };

export class CustomerAlreadyRatedError extends Error {
  constructor() {
    super('RIDE_ALREADY_RATED');
    this.name = 'CustomerAlreadyRatedError';
  }
}

export interface RideCustomerRatingStore {
  /** One rating per ride; throws CustomerAlreadyRatedError on a duplicate. */
  create(input: Omit<CustomerRating, 'id' | 'createdAt'>): Promise<CustomerRating>;
  findByRide(rideId: string): Promise<CustomerRating | null>;
  summaries(customerIds: readonly string[]): Promise<Map<string, CustomerRatingSummary>>;
}

function summary(sum: number, count: number): CustomerRatingSummary {
  return { average: count === 0 ? null : Math.round((sum / count) * 10) / 10, count };
}

export class MemoryRideCustomerRatingStore implements RideCustomerRatingStore {
  private readonly rows = new Map<string, CustomerRating>();

  async create(input: Omit<CustomerRating, 'id' | 'createdAt'>): Promise<CustomerRating> {
    if (this.rows.has(input.rideId)) {
      throw new CustomerAlreadyRatedError();
    }
    const row = { ...input, tags: [...input.tags], id: randomUUID(), createdAt: new Date() };
    this.rows.set(input.rideId, row);
    return { ...row };
  }

  async findByRide(rideId: string): Promise<CustomerRating | null> {
    const row = this.rows.get(rideId);
    return row ? { ...row } : null;
  }

  async summaries(customerIds: readonly string[]): Promise<Map<string, CustomerRatingSummary>> {
    const out = new Map<string, CustomerRatingSummary>();
    for (const id of new Set(customerIds)) {
      const stars = [...this.rows.values()].filter((r) => r.customerId === id).map((r) => r.stars);
      out.set(id, summary(stars.reduce((a, b) => a + b, 0), stars.length));
    }
    return out;
  }
}

export class PrismaRideCustomerRatingStore implements RideCustomerRatingStore {
  constructor(private readonly db: PrismaClient) {}

  async create(input: Omit<CustomerRating, 'id' | 'createdAt'>): Promise<CustomerRating> {
    try {
      return await this.db.customerRating.create({ data: input });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new CustomerAlreadyRatedError();
      }
      throw error;
    }
  }

  findByRide(rideId: string): Promise<CustomerRating | null> {
    return this.db.customerRating.findUnique({ where: { rideId } });
  }

  async summaries(customerIds: readonly string[]): Promise<Map<string, CustomerRatingSummary>> {
    const ids = [...new Set(customerIds)];
    const out = new Map<string, CustomerRatingSummary>(ids.map((id) => [id, summary(0, 0)]));
    if (ids.length === 0) {
      return out;
    }
    const groups = await this.db.customerRating.groupBy({
      by: ['customerId'],
      where: { customerId: { in: ids } },
      _count: { _all: true },
      _sum: { stars: true },
    });
    for (const group of groups) {
      out.set(group.customerId, summary(group._sum.stars ?? 0, group._count._all));
    }
    return out;
  }
}
