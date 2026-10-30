import { describe, expect, it } from 'vitest';
import {
  clampToFareSteps,
  defaultRideVehicleClasses,
  isCarVehicleClassCode,
  quoteVehicleClassFare,
  rideBidCeilingVnd,
  rideBidFloorVnd,
  roundDownToFareStep,
  roundUpToFareStep,
  vehicleClassCodeFromMetadata,
} from './ride-vehicle-class.js';

describe('quoteVehicleClassFare', () => {
  const classes = defaultRideVehicleClasses({ maxFareVnd: 500_000 });

  it('seeds the owner tariff (per-km + minimum per class)', () => {
    expect(classes.map((c) => [c.code, c.baseFareVnd, c.perKmVnd, c.perMinuteVnd, c.minFareVnd])).toEqual([
      ['MOTORBIKE', 0, 5_000, 0, 10_000],
      ['CAR_4', 0, 9_000, 0, 20_000],
      ['CAR_7', 0, 13_000, 0, 25_000],
    ]);
  });

  it('keeps the motorbike reference as distance times the per-km rate', () => {
    const quote = quoteVehicleClassFare({ distanceKm: 8, vehicle: classes[0]! });
    expect(quote.referenceFareVnd).toBe(40_000);
    expect(quote.timeComponentVnd).toBe(0);
  });

  it('uses the class minimum when the distance component is smaller', () => {
    expect(quoteVehicleClassFare({ distanceKm: 1, vehicle: classes[0]! }).referenceFareVnd).toBe(10_000);
    expect(quoteVehicleClassFare({ distanceKm: 1, vehicle: classes[1]! }).referenceFareVnd).toBe(20_000);
    expect(quoteVehicleClassFare({ distanceKm: 1, vehicle: classes[2]! }).referenceFareVnd).toBe(25_000);
  });

  it('quotes CAR_4 at 9.000đ/km', () => {
    const quote = quoteVehicleClassFare({ distanceKm: 8, vehicle: classes[1]! });
    expect(quote.referenceFareVnd).toBe(72_000);
  });

  it('quotes CAR_7 at 13.000đ/km', () => {
    const quote = quoteVehicleClassFare({ distanceKm: 8, vehicle: classes[2]! });
    expect(quote.referenceFareVnd).toBe(104_000);
  });
});

describe('rideBidCeilingVnd', () => {
  it('rounds the +30% ceiling down to the step', () => {
    // 130% of 59.000 = 76.700 → 76.000
    expect(rideBidCeilingVnd(59_000, 130)).toBe(76_000);
    expect(rideBidCeilingVnd(10_000, 130)).toBe(13_000);
    expect(rideBidCeilingVnd(59_000, 0)).toBe(Number.POSITIVE_INFINITY);
  });
});

describe('ride fare rounding step', () => {
  const bike = {
    ...defaultRideVehicleClasses({ maxFareVnd: 500_000 })[0]!,
    perKmVnd: 12_000,
  };

  it('rounds an odd suggested fare up to the next 1.000đ', () => {
    // 4.8363 km × 12.000đ = 58.035,6 → 58.036 before rounding.
    const quote = quoteVehicleClassFare({ distanceKm: 4.8363, vehicle: bike });
    expect(quote.referenceFareVnd).toBe(59_000);
    expect(quote.referenceFareVnd % 1000).toBe(0);
  });

  it('never returns an amount off the step for any distance', () => {
    for (let km = 0.1; km < 40; km += 0.137) {
      const quote = quoteVehicleClassFare({ distanceKm: km, vehicle: bike });
      expect(quote.referenceFareVnd % 1000).toBe(0);
    }
  });

  it('keeps the stepped fare inside odd class bounds', () => {
    expect(clampToFareSteps(9_100, 9_500, 50_500)).toBe(10_000);
    expect(clampToFareSteps(50_200, 9_500, 50_500)).toBe(50_000);
    // Bounds narrower than one step fall back to the plain clamp.
    expect(clampToFareSteps(12_345, 12_100, 12_900)).toBe(12_345);
  });

  it('rounds helpers up and down', () => {
    expect(roundUpToFareStep(23_487)).toBe(24_000);
    expect(roundUpToFareStep(24_000)).toBe(24_000);
    expect(roundDownToFareStep(34_500)).toBe(34_000);
  });

  it('rounds the minimum bid up to the step', () => {
    // 80% of 59.000 = 47.200 → 48.000
    expect(rideBidFloorVnd(59_000, 80)).toBe(48_000);
    expect(rideBidFloorVnd(59_000, 0)).toBe(0);
    expect(rideBidFloorVnd(0, 80)).toBe(0);
  });
});

describe('isCarVehicleClassCode', () => {
  it('detects Car catalog codes only', () => {
    expect(isCarVehicleClassCode('CAR_4')).toBe(true);
    expect(isCarVehicleClassCode('CAR_7')).toBe(true);
    expect(isCarVehicleClassCode('MOTORBIKE')).toBe(false);
  });
});

describe('vehicleClassCodeFromMetadata', () => {
  it('reads an explicit whitelisted code', () => {
    expect(vehicleClassCodeFromMetadata({ vehicleClassCode: 'car_4' })).toBe('CAR_4');
    expect(vehicleClassCodeFromMetadata({ vehicleClassCode: 'CAR_7' })).toBe('CAR_7');
    expect(vehicleClassCodeFromMetadata({ vehicleClassCode: 'MOTORBIKE' })).toBe('MOTORBIKE');
  });

  it('fail-closes unknown codes / free-text / missing metadata (never silent MOTORBIKE)', () => {
    expect(vehicleClassCodeFromMetadata({ vehicleClassCode: 'HONDA_WAVE' })).toBeNull();
    expect(vehicleClassCodeFromMetadata({ vehicleType: 'Ô tô 4 chỗ' })).toBeNull();
    expect(vehicleClassCodeFromMetadata({ vehicleType: 'Xe 7 chỗ' })).toBeNull();
    expect(vehicleClassCodeFromMetadata({ vehicleType: 'Honda AirBlade' })).toBeNull();
    expect(vehicleClassCodeFromMetadata(undefined)).toBeNull();
    expect(vehicleClassCodeFromMetadata(null)).toBeNull();
    expect(vehicleClassCodeFromMetadata({})).toBeNull();
  });
});
