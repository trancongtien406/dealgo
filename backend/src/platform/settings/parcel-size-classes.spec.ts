import { normalizeParcelSizeClasses, PARCEL_SIZE_CLASSES_DEFAULT } from './parcel-size-classes.js';

describe('normalizeParcelSizeClasses (DEC-PROD-071)', () => {
  it('accepts the seeded default', () => {
    const rows = normalizeParcelSizeClasses(PARCEL_SIZE_CLASSES_DEFAULT);
    expect(rows.map((r) => r.code)).toEqual(['S', 'M', 'L', 'XL']);
    expect(rows.find((r) => r.code === 'XL')?.vehicleClassCodes).toEqual(['CAR_4', 'CAR_7']);
  });

  it.each([
    [[], /non-empty/],
    [[{ code: 'Z', maxWeightKg: 1, maxDimsCm: [1, 1, 1], vehicleClassCodes: ['MOTORBIKE'] }], /code/],
    [[{ code: 'S', maxWeightKg: 0, maxDimsCm: [1, 1, 1], vehicleClassCodes: ['MOTORBIKE'] }], /maxWeightKg/],
    [[{ code: 'S', maxWeightKg: 5, maxDimsCm: [1, 1], vehicleClassCodes: ['MOTORBIKE'] }], /maxDimsCm/],
    [[{ code: 'S', maxWeightKg: 5, maxDimsCm: [1, 1, 1], surchargeVnd: 1500, vehicleClassCodes: ['MOTORBIKE'] }], /surchargeVnd/],
    [[{ code: 'S', maxWeightKg: 5, maxDimsCm: [1, 1, 1], vehicleClassCodes: [] }], /vehicleClassCodes/],
  ])('rejects invalid config %#', (raw, message) => {
    expect(() => normalizeParcelSizeClasses(raw)).toThrow(message);
  });

  it('rejects duplicate codes', () => {
    const row = { code: 'S', maxWeightKg: 5, maxDimsCm: [1, 1, 1], vehicleClassCodes: ['MOTORBIKE'] };
    expect(() => normalizeParcelSizeClasses([row, row])).toThrow(/duplicate/);
  });
});
