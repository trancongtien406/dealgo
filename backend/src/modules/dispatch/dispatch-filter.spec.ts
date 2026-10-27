import { boundingBox, filterByDispatchRadius, inBox } from './dispatch-filter.js';

describe('filterByDispatchRadius', () => {
  const items = [
    { id: 'near', pickup: { lat: 10.78, lng: 106.7 } },
    { id: 'far', pickup: { lat: 11.5, lng: 107.5 } },
    { id: 'mid', pickup: { lat: 10.8, lng: 106.72 } },
  ];

  it('caps the list when coordinates are omitted', () => {
    const result = filterByDispatchRadius(items, {}, 5, 2, (item) => item.pickup);
    expect(result.map((item) => item.id)).toEqual(['near', 'far']);
  });

  it('keeps only items within radius when coordinates are provided', () => {
    const result = filterByDispatchRadius(
      items,
      { lat: 10.776889, lng: 106.700806 },
      5,
      20,
      (item) => item.pickup,
    );
    expect(result.map((item) => item.id)).toEqual(['near', 'mid']);
  });

  it('sorts nearest first before applying the cap', () => {
    const origin = { lat: 10.8, lng: 106.72 };
    const result = filterByDispatchRadius(items, origin, 10, 1, (item) => item.pickup);
    expect(result.map((item) => item.id)).toEqual(['mid']);
  });

  it('boundingBox contains the radius circle and inBox checks it', () => {
    const origin = { lat: 10.776889, lng: 106.700806 };
    const box = boundingBox(origin, 5);
    expect(inBox({ lat: 10.8, lng: 106.72 }, box)).toBe(true);
    expect(inBox({ lat: 11.5, lng: 107.5 }, box)).toBe(false);
    // 4.9 km due east and due north are inside
    expect(inBox({ lat: origin.lat, lng: origin.lng + 4.9 / (111.32 * Math.cos((origin.lat * Math.PI) / 180)) }, box)).toBe(true);
    expect(inBox({ lat: origin.lat + 4.9 / 111.32, lng: origin.lng }, box)).toBe(true);
  });
});
