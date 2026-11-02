import { describe, expect, it } from 'vitest';
import {
  normalizeIntercityClasses,
  normalizeIntercityPricing,
} from '../../platform/settings/intercity-settings.js';
import {
  INTERCITY_UNCAPPED_MAX_FARE_VND,
  applyIntercityPricing,
  intercityClassAllowed,
  isIntercityTrip,
  type IntercityConfig,
} from './ride-intercity.js';

const hanoi = { lat: 21.0285, lng: 105.8542 };
const hanoiWest = { lat: 21.038, lng: 105.782 };
const danang = { lat: 16.0612, lng: 108.228 };
const nhaTrang = { lat: 12.2388, lng: 109.1967 };
const cfg = (patch: Partial<IntercityConfig> = {}): IntercityConfig => ({
  enabled: true,
  vehicleClassCodes: [],
  pricing: {},
  maxDistanceKm: 0,
  ...patch,
});

describe('ride intercity (t73u)', () => {
  it('detects pickup-served cross-region trips only', () => {
    expect(isIntercityTrip(hanoi, hanoiWest)).toBe(false);
    expect(isIntercityTrip(hanoi, danang)).toBe(true);
    expect(isIntercityTrip(hanoi, nhaTrang)).toBe(true);
    expect(isIntercityTrip(nhaTrang, hanoi)).toBe(false);
  });

  it('defaults to every class (bike included) and honours an explicit list', () => {
    expect(intercityClassAllowed(cfg(), 'MOTORBIKE')).toBe(true);
    expect(intercityClassAllowed(cfg(), 'CAR_4')).toBe(true);
    expect(intercityClassAllowed(cfg({ vehicleClassCodes: ['CAR_7'] }), 'CAR_4')).toBe(false);
    expect(intercityClassAllowed(cfg({ vehicleClassCodes: ['CAR_7'] }), 'MOTORBIKE')).toBe(false);
  });

  it('lifts the city max fare and applies overrides', () => {
    const car = { code: 'CAR_4', perKmVnd: 10_000, minFareVnd: 30_000, maxFareVnd: 500_000 };
    expect(applyIntercityPricing(car, cfg()).maxFareVnd).toBe(INTERCITY_UNCAPPED_MAX_FARE_VND);
    const o = applyIntercityPricing(car, cfg({ pricing: { CAR_4: { perKmVnd: 8_000, maxFareVnd: 3_000_000 } } }));
    expect(o).toMatchObject({ perKmVnd: 8_000, minFareVnd: 30_000, maxFareVnd: 3_000_000 });
  });

  it('validates admin JSON', () => {
    expect(normalizeIntercityClasses(['CAR_4', 'CAR_4'])).toEqual(['CAR_4']);
    expect(() => normalizeIntercityClasses(['car 4'])).toThrow();
    expect(() => normalizeIntercityPricing({ CAR_4: { minFareVnd: 5, maxFareVnd: 1 } })).toThrow();
    expect(() => normalizeIntercityPricing({ CAR_4: { perKmVnd: -1 } })).toThrow();
  });
});
