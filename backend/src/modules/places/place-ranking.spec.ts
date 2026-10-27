import { describe, expect, it } from 'vitest';
import type { PlaceSuggestion } from '../../integrations/maps/maps-port.js';
import { photonToSuggestions } from '../../integrations/maps/osm-search.js';
import { distanceTier, parsePlaceQuery, rankPlaces, textScore, tidyAddress } from './place-ranking.js';

const DN = { lat: 16.0544, lng: 108.2022 };
const street = (name: string, address: string, lat: number, lng: number, provider: PlaceSuggestion['provider'] = 'osm'): PlaceSuggestion => ({
  name, address, lat, lng, provider, kind: 'street',
});

describe('parsePlaceQuery', () => {
  it('splits a leading house number from the street', () => {
    expect(parsePlaceQuery(' 12  Nguyễn Hoàng ')).toMatchObject({ houseNumber: '12', street: 'Nguyễn Hoàng', folded: 'nguyen hoang' });
    expect(parsePlaceQuery('số 45/7a Lê Duẩn')).toMatchObject({ houseNumber: '45/7A', street: 'Lê Duẩn' });
    expect(parsePlaceQuery('Bạch Đằng')).toMatchObject({ houseNumber: null, street: 'Bạch Đằng' });
    expect(parsePlaceQuery('12')).toMatchObject({ houseNumber: null, street: '12' });
  });
});

describe('rankPlaces', () => {
  const hoiAn = street('Nguyễn Hoàng', 'Nguyễn Hoàng, Minh An, 51300, Hội An, Việt Nam', 15.879, 108.33, 'mapbox');
  const hoaCuong = street('Đường Nguyễn Hoàng', 'Đường Nguyễn Hoàng, Hòa Cường, Đà Nẵng', 16.0603, 108.2101);
  const segment = street('Đường Nguyễn Hoàng', 'Đường Nguyễn Hoàng, Hòa Cường, Đà Nẵng', 16.0625, 108.2118);
  const alley = street('Kiệt 376 Nguyễn Hoàng', 'Kiệt 376 Nguyễn Hoàng, Thanh Khê, Đà Nẵng', 16.0601, 108.2097);
  const hue = street('Cầu Nguyễn Hoàng', 'Cầu Nguyễn Hoàng, Huế', 16.47, 107.58, 'mapbox');

  it('puts the current city first, then nearby provinces, then further', () => {
    const out = rankPlaces([hue, hoiAn, alley, hoaCuong], parsePlaceQuery('nguyen hoang'), DN, 5);
    expect(out.map((p) => p.name)).toEqual(['Đường Nguyễn Hoàng', 'Kiệt 376 Nguyễn Hoàng', 'Nguyễn Hoàng', 'Cầu Nguyễn Hoàng']);
    expect(out[0]!.distanceKm).toBeCloseTo(1.3, 0);
    expect(out[2]!.address).toBe('Nguyễn Hoàng, Minh An, Hội An');
  });

  it('keeps one row per street per ward', () => {
    expect(rankPlaces([hoaCuong, segment], parsePlaceQuery('Nguyễn Hoàng'), DN, 5)).toHaveLength(1);
  });

  it('puts a typed house number on the matching street, flagged approximate', () => {
    const out = rankPlaces([hoaCuong, alley], parsePlaceQuery('12 Nguyễn Hoàng'), DN, 5);
    expect(out[0]).toMatchObject({ name: '12 Nguyễn Hoàng', address: '12 Nguyễn Hoàng, Hòa Cường, Đà Nẵng', approximate: true });
    expect(out[1]).toMatchObject({ name: 'Kiệt 376 Nguyễn Hoàng' });
    expect(out[1]!.approximate).toBeUndefined();
  });

  it('keeps an exact address from the provider', () => {
    const exact: PlaceSuggestion = { ...hoaCuong, name: '12 Nguyễn Hoàng', kind: 'address' };
    expect(rankPlaces([exact], parsePlaceQuery('12 Nguyễn Hoàng'), DN, 5)[0]!.approximate).toBeUndefined();
  });

  it('drops text misses when anything matches and ranks without a bias point', () => {
    const miss = street('Hùng Vương', 'Hùng Vương, Đà Nẵng', 16.06, 108.21);
    const out = rankPlaces([miss, hoiAn], parsePlaceQuery('Nguyen Hoang'), undefined, 5);
    expect(out.map((p) => p.name)).toEqual(['Nguyễn Hoàng']);
    expect(out[0]!.distanceKm).toBeUndefined();
  });
});

describe('helpers', () => {
  it('scores text diacritics-insensitively', () => {
    const q = parsePlaceQuery('le duan');
    expect(textScore(street('Đường Lê Duẩn', 'x', 0, 0), q)).toBe(3);
    expect(textScore(street('Lê Duẩn Plaza', 'x', 0, 0), q)).toBe(2);
    expect(textScore(street('Kiệt 478 Lê Duẩn', 'x', 0, 0), q)).toBe(1.2);
    expect(textScore(street('Hùng Vương', 'x', 0, 0), q)).toBe(0);
  });

  it('tiers distance', () => {
    expect([5, 40, 200, 600].map(distanceTier)).toEqual([3, 2, 1, 0]);
    expect(distanceTier(null)).toBe(0);
  });

  it('tidies provider labels', () => {
    expect(tidyAddress('Bạch Đằng, Phường 15, 72300, Gia Định, Việt Nam')).toBe('Bạch Đằng, Phường 15, Gia Định');
  });

  it('maps Photon features', () => {
    const out = photonToSuggestions({
      features: [
        { geometry: { coordinates: [108.21, 16.06] }, properties: { name: 'Đường Nguyễn Hoàng', district: 'Hòa Cường', city: 'Đà Nẵng', osm_key: 'highway' } },
        { geometry: { coordinates: [108.2, 16.05] }, properties: { street: 'Lê Duẩn', housenumber: '20', city: 'Đà Nẵng', osm_key: 'building' } },
        { geometry: { coordinates: [] }, properties: { name: 'x' } },
      ],
    });
    expect(out).toEqual([
      { lat: 16.06, lng: 108.21, name: 'Đường Nguyễn Hoàng', address: 'Đường Nguyễn Hoàng, Hòa Cường, Đà Nẵng', provider: 'osm', kind: 'street' },
      { lat: 16.05, lng: 108.2, name: '20 Lê Duẩn', address: '20 Lê Duẩn, Đà Nẵng', provider: 'osm', kind: 'address' },
    ]);
  });
});
