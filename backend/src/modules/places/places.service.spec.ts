import { describe, expect, it } from 'vitest';
import {
  MockMapsPort,
  UnavailableMapsPort,
  foldVietnamese,
} from '../../integrations/maps/maps-port.js';
import { MapsProviderSettings } from '../../integrations/maps/maps-provider-settings.js';
import type { GoogleMapsPort } from '../../integrations/maps/google-maps.js';
import { PlacesService } from './places.service.js';

describe('PlacesService', () => {
  it('finds Da Nang places with or without diacritics', async () => {
    const places = new PlacesService(new MockMapsPort());
    const withMarks = await places.search('Chợ Hàn');
    expect(withMarks.available).toBe(true);
    expect(withMarks.items[0]).toMatchObject({
      name: 'Chợ Hàn',
      provider: 'mock',
    });
    expect(withMarks.items[0].lat).toBeCloseTo(16.068, 3);
    const folded = await places.search('cho han');
    expect(folded.items.map((p) => p.name)).toContain('Chợ Hàn');
    expect((await places.search('zzzz không có')).items).toEqual([]);
    expect((await places.search('a')).items).toEqual([]);
    expect(
      (await places.search('đà nẵng', 3)).items.length,
    ).toBeLessThanOrEqual(3);
  });

  it('reports an unconfigured provider instead of failing', async () => {
    const places = new PlacesService(new UnavailableMapsPort());
    expect(await places.search('chợ hàn')).toEqual({
      items: [],
      available: false,
    });
    expect(await places.reverse(16.068, 108.2235)).toEqual({
      place: null,
      available: false,
    });
  });

  it('names a GPS fix after the nearest landmark, keeping the fix', async () => {
    const places = new PlacesService(new MockMapsPort());
    const near = await places.reverse(16.0682, 108.2237);
    expect(near.place).toMatchObject({
      name: 'Gần Chợ Hàn',
      lat: 16.0682,
      lng: 108.2237,
    });
    expect((await places.reverse(10.77, 106.7)).place).toBeNull();
  });

  it('reuses a reverse answer for the same ~11 m cell for an hour', async () => {
    const maps = new MockMapsPort();
    let calls = 0;
    const original = maps.reverseGeocode.bind(maps);
    maps.reverseGeocode = async (p) => {
      calls += 1;
      return original(p);
    };
    const places = new PlacesService(maps);
    let clock = 1_000;
    places.now = () => clock;

    const first = await places.reverse(16.06821, 108.22371);
    const again = await places.reverse(16.06824, 108.22368);
    expect(calls).toBe(1);
    expect(again.place).toMatchObject({
      name: first.place?.name,
      lat: 16.06824,
      lng: 108.22368,
    });
    await places.reverse(10.77, 106.7);
    await places.reverse(10.77001, 106.70001);
    expect(calls).toBe(2);

    clock += 60 * 60 * 1000;
    await places.reverse(16.06821, 108.22371);
    expect(calls).toBe(3);
  });

  it('does not cache an unavailable provider', async () => {
    const maps = new UnavailableMapsPort();
    let calls = 0;
    const original = maps.reverseGeocode.bind(maps);
    maps.reverseGeocode = async (p) => {
      calls += 1;
      return original(p);
    };
    const places = new PlacesService(maps);
    await places.reverse(16.068, 108.2235);
    await places.reverse(16.068, 108.2235);
    expect(calls).toBe(2);
  });

  describe('with OSM streets', () => {
    const DN = { lat: 16.0544, lng: 108.2022 };
    const osmStreet = { name: 'Đường Nguyễn Hoàng', address: 'Đường Nguyễn Hoàng, Hòa Cường, Đà Nẵng', lat: 16.0603, lng: 108.2101, provider: 'osm' as const, kind: 'street' as const };
    const mapboxHoiAn = { name: 'Nguyễn Hoàng', address: 'Nguyễn Hoàng, Minh An, Hội An', lat: 15.879, lng: 108.33, provider: 'mapbox' as const, kind: 'street' as const };
    function setup(local: unknown[], national: unknown[] = []) {
      const calls: Array<{ query: string; bbox?: readonly number[] }> = [];
      let mapboxCalls = 0;
      const maps = Object.assign(new MockMapsPort(), {
        searchPlaces: async () => {
          mapboxCalls += 1;
          return [mapboxHoiAn];
        },
      });
      const osm = {
        search: async (query: string, _limit: number, _near?: unknown, bbox?: readonly number[]) => {
          calls.push({ query, bbox });
          return (bbox ? local : national) as never;
        },
      };
      return { places: new PlacesService(maps, osm), calls, mapbox: () => mapboxCalls };
    }

    it('ranks city streets first and searches the street part of a house number', async () => {
      const { places, calls } = setup([osmStreet]);
      const out = await places.search('12 Nguyễn Hoàng', 5, DN);
      expect(calls).toHaveLength(1);
      expect(calls[0]!.query).toBe('Nguyễn Hoàng');
      expect(out.items.map((p) => [p.name, p.approximate ?? false])).toEqual([
        ['12 Nguyễn Hoàng', true],
        ['12 Nguyễn Hoàng', true],
      ]);
      expect(out.items[0]!.address).toContain('Hòa Cường');
    });

    it('widens to the whole country when the city has no match', async () => {
      const { places, calls } = setup([], [osmStreet]);
      const out = await places.search('Nguyễn Hoàng', 5, DN);
      expect(calls.map((c) => c.bbox === undefined)).toEqual([false, true]);
      expect(out.items[0]!.provider).toBe('osm');
    });

    it('caches by folded query and ~1 km proximity for 10 minutes', async () => {
      const { places, mapbox } = setup([osmStreet]);
      let now = 0;
      places.now = () => now;
      await places.search('Nguyễn Hoàng', 5, DN);
      await places.search('nguyen hoang', 5, { lat: 16.0541, lng: 108.2019 });
      expect(mapbox()).toBe(1);
      now = 11 * 60 * 1000;
      await places.search('nguyen hoang', 5, DN);
      expect(mapbox()).toBe(2);
    });

    it('shows Google results alone with attribution, OSM only when Google has nothing', async () => {
      const googleItem = { name: 'Nguyễn Hoàng', address: 'Nguyễn Hoàng, Hải Châu, Đà Nẵng', lat: 16.061, lng: 108.211, provider: 'google' as const, kind: 'street' as const };
      let googleItems = [googleItem];
      const maps = Object.assign(new MockMapsPort(), { searchPlaces: async () => googleItems });
      const osm = { search: async () => [osmStreet] };
      const places = new PlacesService(maps, osm);
      const out = await places.search('Nguyễn Hoàng', 5, DN);
      expect(out.attribution).toBe('google');
      expect(out.items.every((p) => p.provider === 'google')).toBe(true);
      googleItems = [];
      const empty = await places.search('Nguyễn Hoàng xyz', 5, DN);
      expect(empty.attribution).toBeUndefined();
    });

    it('keys the caches by the admin-chosen provider', async () => {
      let choice = 'mapbox';
      const google = {} as GoogleMapsPort;
      const selector = new MapsProviderSettings({ getString: async () => choice }, google);
      let searches = 0;
      let reverses = 0;
      const maps = Object.assign(new MockMapsPort(), {
        searchPlaces: async () => {
          searches += 1;
          return [mapboxHoiAn];
        },
        reverseGeocode: async () => {
          reverses += 1;
          return null;
        },
      });
      const places = new PlacesService(maps, null, selector);
      await places.search('Nguyễn Hoàng', 5, DN);
      await places.reverse(16.05, 108.2);
      choice = 'google';
      await places.search('Nguyễn Hoàng', 5, DN);
      await places.reverse(16.05, 108.2);
      expect([searches, reverses]).toEqual([2, 2]);
    });

    it('stays available on OSM alone', async () => {
      const osm = { search: async () => [osmStreet] };
      const out = await new PlacesService(new UnavailableMapsPort(), osm).search('Nguyễn Hoàng', 5, DN);
      expect(out.available).toBe(true);
      expect(out.items).toHaveLength(1);
    });
  });

  it('folds Vietnamese text for matching', () => {
    expect(foldVietnamese('  Đường  Bạch Đằng ')).toBe('duong bach dang');
  });
});
