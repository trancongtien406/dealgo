import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { haversineKm } from '../../shared/geo/haversine.js';

export interface PriceQuote {
  quoteId: string;
  baseAmount: number;
  surgeMultiplier: number;
  discountAmount: number;
  finalAmount: number;
  currency: string;
  expiresAt: Date;
}

export type QuoteFareInput = {
  distanceKm: number;
  perKm: number;
  minimum: number;
  surgeMultiplier?: number;
  discountAmount?: number;
  ttlSeconds?: number;
};

@Injectable()
export class PricingService {
  /**
   * Quotes reference fare for two-wheel rides.
   * Formula: max(round(distanceKm * perKm), minimum)
   */
  quoteRideReferenceFare(distanceKm: number, perKm: number, minimum: number): number {
    return Math.max(Math.round(distanceKm * perKm), minimum);
  }

  /**
   * Quotes distance-based food delivery fare capped between min and max.
   */
  quoteDeliveryFare(
    distanceKm: number,
    perKm: number,
    minimum: number,
    maximum: number,
  ): number {
    const raw = Math.round(distanceKm * perKm);
    return Math.max(minimum, Math.min(maximum, raw));
  }

  /**
   * Generates a structured price quote with TTL and idempotency token.
   */
  createQuote(input: QuoteFareInput): PriceQuote {
    const surge = input.surgeMultiplier ?? 1.0;
    const discount = input.discountAmount ?? 0;
    const base = this.quoteRideReferenceFare(input.distanceKm, input.perKm, input.minimum);
    const finalAmount = Math.max(input.minimum, Math.round(base * surge) - discount);
    const ttlMs = (input.ttlSeconds ?? 300) * 1000;

    return {
      quoteId: randomUUID(),
      baseAmount: base,
      surgeMultiplier: surge,
      discountAmount: discount,
      finalAmount,
      currency: 'VND',
      expiresAt: new Date(Date.now() + ttlMs),
    };
  }

  calculateDistanceKm(
    from: { lat: number; lng: number },
    to: { lat: number; lng: number },
  ): number {
    return haversineKm(from, to);
  }
}
