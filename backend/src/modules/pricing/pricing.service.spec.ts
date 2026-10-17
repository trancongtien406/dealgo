import { describe, expect, it } from 'vitest';
import { PricingService } from './pricing.service.js';

describe('PricingService', () => {
  const pricing = new PricingService();

  it('calculates ride reference fare correctly with floor minimum', () => {
    // 5.2 km * 8000 = 41600
    expect(pricing.quoteRideReferenceFare(5.2, 8000, 10000)).toBe(41600);
    // 0.5 km * 8000 = 4000 < minimum 10000 -> 10000
    expect(pricing.quoteRideReferenceFare(0.5, 8000, 10000)).toBe(10000);
  });

  it('calculates food delivery fare bounded between minimum and maximum', () => {
    // 2 km * 3000 = 6000
    expect(pricing.quoteDeliveryFare(2, 3000, 5000, 100000)).toBe(6000);
    // 1 km * 3000 = 3000 < minimum 5000 -> 5000
    expect(pricing.quoteDeliveryFare(1, 3000, 5000, 100000)).toBe(5000);
    // 50 km * 3000 = 150000 > maximum 100000 -> 100000
    expect(pricing.quoteDeliveryFare(50, 3000, 5000, 100000)).toBe(100000);
  });

  it('generates structured quote with surge and discount', () => {
    const quote = pricing.createQuote({
      distanceKm: 5,
      perKm: 8000,
      minimum: 10000,
      surgeMultiplier: 1.2,
      discountAmount: 5000,
    });

    expect(quote.quoteId).toBeDefined();
    expect(quote.baseAmount).toBe(40000);
    // 40000 * 1.2 = 48000 - 5000 = 43000
    expect(quote.finalAmount).toBe(43000);
    expect(quote.currency).toBe('VND');
    expect(quote.expiresAt.getTime()).toBeGreaterThan(Date.now());
  });
});
