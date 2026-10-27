import { describe, expect, it } from 'vitest';
import {
  defaultRideVehicleClasses,
  isCarVehicleClassCode,
  quoteVehicleClassFare,
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
    // durationMin = round(8/22*60) = 22; 15000 + 8*12000 + 22*300 = 117600
    expect(quote.durationMin).toBe(22);
    expect(quote.referenceFareVnd).toBe(117_600);
  });

  it('quotes CAR_7 with DRAFT/ADMIN_EDITABLE seeds (not OPEN-003 law)', () => {
    const car = classes[2]!;
    expect(car.code).toBe('CAR_7');
    expect(car.baseFareVnd).toBe(20_000);
    expect(car.perKmVnd).toBe(14_000);
    const quote = quoteVehicleClassFare({ distanceKm: 8, vehicle: car });
    // durationMin = round(8/20*60) = 24; 20000 + 8*14000 + 24*400 = 141600
    expect(quote.durationMin).toBe(24);
    expect(quote.referenceFareVnd).toBe(141_600);
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
