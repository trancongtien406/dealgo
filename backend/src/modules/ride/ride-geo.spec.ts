import { haversineKm, quoteReferenceFareVnd } from './ride-geo.js';

describe('ride reference fare', () => {
  it('measures about 111.195 km per degree of longitude at the equator', () => {
    expect(haversineKm({ lat: 0, lng: 0 }, { lat: 0, lng: 1 })).toBeCloseTo(111.195, 2);
  });

  it('rounds to integer VND and keeps the default minimum', () => {
    expect(quoteReferenceFareVnd(0, 8000, 10_000)).toBe(10_000);
    expect(quoteReferenceFareVnd(2, 8000, 10_000)).toBe(16_000);
    expect(Number.isInteger(quoteReferenceFareVnd(1.24, 8000, 10_000))).toBe(true);
  });
});
