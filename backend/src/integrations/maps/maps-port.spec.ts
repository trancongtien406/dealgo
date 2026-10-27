import { haversineKm } from '../../modules/ride/ride-geo.js';
import {
  MapboxMapsPort,
  MockMapsPort,
  UnavailableMapsError,
  UnavailableMapsPort,
  resolveRouteDistanceKm,
} from './maps-port.js';
import { MOCK_DANANG_CENTER } from './maps.constants.js';

describe('MockMapsPort', () => {
  const maps = new MockMapsPort();

  it('geocodes Da Nang landmarks deterministically', async () => {
    const airport = await maps.geocode('Da Nang Airport DAD');
    expect(airport.provider).toBe('mock');
    expect(airport.lat).toBeCloseTo(16.0439, 3);
    expect(airport.lng).toBeCloseTo(108.1994, 3);

    const fallback = await maps.geocode('unknown place');
    expect(fallback.lat).toBe(MOCK_DANANG_CENTER.lat);
    expect(fallback.lng).toBe(MOCK_DANANG_CENTER.lng);
  });

  it('returns haversine route distance', async () => {
    const origin = { lat: 16.05, lng: 108.2 };
    const destination = { lat: 16.07, lng: 108.22 };
    await expect(maps.routeDistanceKm(origin, destination)).resolves.toBeCloseTo(
      haversineKm(origin, destination),
      6,
    );
  });
});

describe('UnavailableMapsPort', () => {
  it('throws UnavailableMapsError', async () => {
    const maps = new UnavailableMapsPort();
    await expect(maps.geocode('x')).rejects.toBeInstanceOf(UnavailableMapsError);
    await expect(maps.routeDistanceKm({ lat: 0, lng: 0 }, { lat: 1, lng: 1 })).rejects.toBeInstanceOf(
      UnavailableMapsError,
    );
  });
});

describe('resolveRouteDistanceKm', () => {
  it('falls back to haversine when maps is unavailable', async () => {
    const origin = { lat: 16.05, lng: 108.2 };
    const destination = { lat: 16.07, lng: 108.22 };
    const distance = await resolveRouteDistanceKm(new UnavailableMapsPort(), origin, destination);
    expect(distance).toBeCloseTo(haversineKm(origin, destination), 6);
  });
});

describe('MapboxMapsPort', () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('maps geocode features and keeps the token in the request URL', async () => {
    globalThis.fetch = (async (input: RequestInfo | URL) => {
      const url = input instanceof Request ? input.url : input.toString();
      expect(url).toContain('api.mapbox.com/geocoding/v5/mapbox.places/');
      expect(url).toContain('access_token=pk.test');
      return new Response(
        JSON.stringify({
          features: [
            {
              text: 'Cầu Rồng',
              place_name: 'Cầu Rồng, Đà Nẵng, Vietnam',
              center: [108.2275, 16.061],
            },
          ],
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }) as typeof fetch;

    const maps = new MapboxMapsPort('pk.test');
    const hit = await maps.geocode('Cầu Rồng');
    expect(hit.provider).toBe('mapbox');
    expect(hit.lat).toBeCloseTo(16.061, 3);
    expect(hit.lng).toBeCloseTo(108.2275, 3);
    expect(hit.label).toContain('Cầu Rồng');

    const places = await maps.searchPlaces('Cầu Rồng', 5);
    expect(places[0]?.provider).toBe('mapbox');
    expect(places[0]?.name).toBe('Cầu Rồng');
  });

  it('reads driving distance meters from Directions', async () => {
    globalThis.fetch = (async () =>
      new Response(JSON.stringify({ routes: [{ distance: 5574 }] }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })) as typeof fetch;
    const maps = new MapboxMapsPort('pk.test');
    await expect(
      maps.routeDistanceKm({ lat: 16.05, lng: 108.2 }, { lat: 16.07, lng: 108.22 }),
    ).resolves.toBeCloseTo(5.574, 3);
  });

  it('degrades to UnavailableMapsError on HTTP failure', async () => {
    globalThis.fetch = (async () =>
      new Response('nope', { status: 401 })) as typeof fetch;
    const maps = new MapboxMapsPort('pk.test');
    await expect(maps.geocode('x')).rejects.toBeInstanceOf(UnavailableMapsError);
  });
});
