import { filterByDispatchRadius } from './dispatch-filter.js';

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
});
