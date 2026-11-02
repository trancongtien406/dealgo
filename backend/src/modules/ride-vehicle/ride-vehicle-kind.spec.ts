import { afterEach, describe, expect, it } from 'vitest';
import {
  isBikeClass,
  isCarVehicleClassCode,
  registerVehicleClassKinds,
  vehicleClassCodeFromMetadata,
  vehicleKindOf,
} from './ride-vehicle-class.js';
import { licenseClassCoversVehicle, requiredPartnerDocuments } from '../partner/partner.constants.js';
import { driverCommissionSettingKey } from '../earnings/earnings.service.js';

describe('vehicle class kind (RIDE-004 / RIDE-005)', () => {
  afterEach(() => registerVehicleClassKinds([]));

  it('keeps legacy codes working without a catalog', () => {
    expect(vehicleKindOf('MOTORBIKE')).toBe('BIKE');
    expect(isCarVehicleClassCode('CAR_4')).toBe(true);
    expect(isCarVehicleClassCode('CAR_7')).toBe(true);
    expect(isCarVehicleClassCode('MOTORBIKE')).toBe(false);
  });

  it('derives docs, licence, commission and KYC acceptance from the catalog kind', () => {
    registerVehicleClassKinds([
      { code: 'MOTORBIKE', kind: 'BIKE' },
      { code: 'CAR_4', kind: 'CAR' },
      { code: 'LUX_CAR', kind: 'CAR' },
      { code: 'EBIKE', kind: 'BIKE' },
    ]);
    expect(isCarVehicleClassCode('LUX_CAR')).toBe(true);
    expect(isBikeClass('EBIKE')).toBe(true);
    expect(requiredPartnerDocuments('DRIVER', { vehicleClassCode: 'LUX_CAR', carExtraDocsGate: true })).toContain(
      'VEHICLE_INSURANCE',
    );
    expect(licenseClassCoversVehicle('B', 'LUX_CAR')).toBe(true);
    expect(licenseClassCoversVehicle('A1', 'LUX_CAR')).toBe(false);
    expect(licenseClassCoversVehicle('A1', 'EBIKE')).toBe(true);
    expect(driverCommissionSettingKey('RIDE', 'LUX_CAR')).toBe('RIDE_COMMISSION_CAR_PERCENT');
    expect(driverCommissionSettingKey('RIDE', 'EBIKE')).toBe('RIDE_COMMISSION_BIKE_PERCENT');
    expect(vehicleClassCodeFromMetadata({ vehicleClassCode: 'lux_car' })).toBe('LUX_CAR');
  });
});
