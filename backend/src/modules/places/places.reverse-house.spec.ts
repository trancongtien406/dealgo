import { describe, expect, it } from 'vitest';
import type { MapsPort, PlaceSuggestion } from '../../integrations/maps/maps-port.js';
import { PlacesService, mergeReverse } from './places.service.js';

const FIX = { lat: 16.0428, lng: 108.242 };
// Real Mapbox v5 answer here (prod, 2026-10-29): street only, no house number.
const mapboxStreet: PlaceSuggestion = {
  lat: 16.04279, lng: 108.24203,
  name: 'Đường Mỹ Đa Đông 7',
  address: 'Đường Mỹ Đa Đông 7, Mỹ An, Ngũ Hành Sơn, Đà Nẵng',
  provider: 'mapbox', kind: 'street',
};
const osmHouse = (n: string, dLat = 0.0001): PlaceSuggestion => ({
  lat: FIX.lat + dLat, lng: FIX.lng,
  name: `${n} Đường Mỹ Đa Đông 7`,
  address: `${n} Đường Mỹ Đa Đông 7, Ngũ Hành Sơn, Đà Nẵng`,
  provider: 'osm', kind: 'address',
});

describe('reverse geocode: house number from OSM', () => {
  it('prefixes the nearest OSM house number and keeps the provider ward/district tail', () => {
    const out = mergeReverse(FIX, mapboxStreet, [osmHouse('36', 0.0002), osmHouse('34')]);
    expect(out).toMatchObject({
      name: '34 Đường Mỹ Đa Đông 7',
      address: '34 Đường Mỹ Đa Đông 7, Mỹ An, Ngũ Hành Sơn, Đà Nẵng',
      lat: FIX.lat, lng: FIX.lng, kind: 'address',
    });
  });

  it('falls back to the nearest street when no house is within 40 m', () => {
    expect(mergeReverse(FIX, mapboxStreet, [osmHouse('34', 0.001)])).toBe(mapboxStreet);
  });

  it('uses OSM street when the provider has nothing', () => {
    const street: PlaceSuggestion = { ...mapboxStreet, provider: 'osm', kind: 'street', address: 'Đường Mỹ Đa Đông 7, Ngũ Hành Sơn, Đà Nẵng' };
    expect(mergeReverse(FIX, null, [street])).toMatchObject({ name: 'Đường Mỹ Đa Đông 7', lat: FIX.lat });
  });

  it('PlacesService.reverse asks OSM in parallel and survives an OSM failure', async () => {
    const maps = { reverseGeocode: async () => mapboxStreet } as unknown as MapsPort;
    const ok = new PlacesService(maps, { search: async () => [], reverse: async () => [osmHouse('34')] });
    expect((await ok.reverse(FIX.lat, FIX.lng)).place?.name).toBe('34 Đường Mỹ Đa Đông 7');
    const broken = new PlacesService(maps, { search: async () => [], reverse: async () => { throw new Error('down'); } });
    expect((await broken.reverse(FIX.lat, FIX.lng)).place?.name).toBe('Đường Mỹ Đa Đông 7');
  });
});
