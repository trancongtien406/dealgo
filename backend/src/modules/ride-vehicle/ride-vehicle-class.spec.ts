import { describe, expect, it } from 'vitest';
import {
  clampToFareSteps,
  defaultRideVehicleClasses,
  isCarVehicleClassCode,
  quoteVehicleClassFare,
  rideBidFloorVnd,
  roundDownToFareStep,
  roundUpToFareStep,
  vehicleClassCodeFromMetadata,
} from './ride-vehicle-class.js';

describe('quoteVehicleClassFare', () => {
  const classes = defaultRideVehicleClasses({
    minFareVnd: 10_000,
    maxFareVnd: 500_000,
    perKmVnd: 8_000,
  });

  it('keeps the motorbike reference as distance times the per-km rate', () => {
    const bike = classes[0]!;
    const quote = quoteVehicleClassFare({ distanceKm: 8, vehicle: bike });
    expect(quote.referenceFareVnd).toBe(64_000);
    expect(quote.timeComponentVnd).toBe(0);
  });

  it('uses the class minimum when the distance component is smaller', () => {
    const bike = classes[0]!;
    const quote = quoteVehicleClassFare({ distanceKm: 0.2, vehicle: bike });
    expect(quote.referenceFareVnd).toBe(10_000);
  });

  it('quotes CAR_4 with DRAFT/ADMIN_EDITABLE seeds (not OPEN-003 law)', () => {
    const car = classes[1]!;
    expect(car.code).toBe('CAR_4');
    expect(car.seats).toBe(4);
    expect(car.baseFareVnd).toBe(15_000);
    expect(car.perKmVnd).toBe(12_000);
    expect(car.perMinuteVnd).toBe(300);
    expect(car.minFareVnd).toBe(25_000);
    expect(car.maxFareVnd).toBe(800_000);
    const quote = quoteVehicleClassFare({ distanceKm: 8, vehicle: car });
    // durationMin = round(8/22*60) = 22; 15000 + 8*12000 + 22*300 = 117600 → 118000
    expect(quote.durationMin).toBe(22);
    expect(quote.referenceFareVnd).toBe(118_000);
  });

  it('quotes CAR_7 with DRAFT/ADMIN_EDITABLE seeds (not OPEN-003 law)', () => {
    const car = classes[2]!;
    expect(car.code).toBe('CAR_7');
    expect(car.baseFareVnd).toBe(20_000);
    expect(car.perKmVnd).toBe(14_000);
    const quote = quoteVehicleClassFare({ distanceKm: 8, vehicle: car });
    // durationMin = round(8/20*60) = 24; 20000 + 8*14000 + 24*400 = 141600 → 142000
    expect(quote.durationMin).toBe(24);
    expect(quote.referenceFareVnd).toBe(142_000);
  });
});

describe('ride fare rounding step', () => {
  const bike = defaultRideVehicleClasses({
    minFareVnd: 10_000,
    maxFareVnd: 500_000,
    perKmVnd: 12_000,
  })[0]!;

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
