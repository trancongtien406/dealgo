import { describe, expect, it, vi } from 'vitest';
import {
  GoogleMapsPort,
  decodePolyline,
  googleKind,
  parseDurationSec,
  stripCountry,
  type GoogleFetch,
} from './google-maps.js';
import { UnavailableMapsError } from './maps-port.js';

const KEY = 'test-key';
const NEAR = { lat: 16.0544, lng: 108.2022 };

type Call = { url: string; init: Parameters<GoogleFetch>[1] };

function fakeFetch(routes: Record<string, (call: Call) => unknown>, status = 200) {
  const calls: Call[] = [];
  const fetcher = vi.fn<GoogleFetch>(async (url, init) => {
    const call = { url, init };
    calls.push(call);
    const match = Object.keys(routes).find((prefix) => url.startsWith(prefix));
    const body = match ? routes[match](call) : {};
    return { ok: status < 400, status, json: async () => body };
  });
  return { fetcher, calls };
}

const AUTOCOMPLETE = {
  suggestions: [
    {
      placePrediction: {
        placeId: 'p-cho-han',
        text: { text: 'Chợ Hàn, Trần Phú, Hải Châu, Đà Nẵng, Việt Nam' },
        structuredFormat: { mainText: { text: 'Chợ Hàn' }, secondaryText: { text: 'Trần Phú, Hải Châu' } },
        types: ['establishment', 'point_of_interest'],
      },
    },
    {
      placePrediction: {
        placeId: 'p-street',
        text: { text: 'Nguyễn Văn Linh, Đà Nẵng, Việt Nam' },
        structuredFormat: { mainText: { text: 'Nguyễn Văn Linh' } },
        types: ['route'],
      },
    },
    { queryPrediction: { text: { text: 'ignored' } } },
  ],
};

describe('GoogleMapsPort', () => {
  it('searches with Autocomplete (New) biased to the rider, then resolves coordinates once per place', async () => {
    const { fetcher, calls } = fakeFetch({
      'https://places.googleapis.com/v1/places:autocomplete': () => AUTOCOMPLETE,
      'https://places.googleapis.com/v1/places/p-cho-han': () => ({ location: { latitude: 16.068, longitude: 108.2235 } }),
      'https://places.googleapis.com/v1/places/p-street': () => ({ location: { latitude: 16.06, longitude: 108.21 } }),
    });
    const google = new GoogleMapsPort(KEY, fetcher);
    const items = await google.searchPlaces('chợ hàn', 10, NEAR);

    expect(items).toEqual([
      { lat: 16.068, lng: 108.2235, name: 'Chợ Hàn', address: 'Chợ Hàn, Trần Phú, Hải Châu, Đà Nẵng', provider: 'google', kind: 'poi' },
      { lat: 16.06, lng: 108.21, name: 'Nguyễn Văn Linh', address: 'Nguyễn Văn Linh, Đà Nẵng', provider: 'google', kind: 'street' },
    ]);
    const auto = calls[0];
    expect(auto.init.method).toBe('POST');
    expect(auto.init.headers['X-Goog-Api-Key']).toBe(KEY);
    expect(auto.init.headers['X-Goog-FieldMask']).toContain('suggestions.placePrediction.placeId');
    expect(JSON.parse(auto.init.body ?? '{}')).toMatchObject({
      input: 'chợ hàn',
      languageCode: 'vi',
      regionCode: 'vn',
      includedRegionCodes: ['vn'],
      locationBias: { circle: { center: { latitude: NEAR.lat, longitude: NEAR.lng }, radius: 50_000 } },
    });
    // Place Details asks only for `location` (Essentials SKU).
    expect(calls[1].init.headers['X-Goog-FieldMask']).toBe('location');

    await google.searchPlaces('chợ hàn', 10, NEAR);
    const detailCalls = calls.filter((c) => c.url.startsWith('https://places.googleapis.com/v1/places/p-'));
    expect(detailCalls).toHaveLength(2); // cached by place ID
  });

  it('skips the call for one-letter queries and caps predictions at the limit', async () => {
    const { fetcher, calls } = fakeFetch({
      'https://places.googleapis.com/v1/places:autocomplete': () => AUTOCOMPLETE,
      'https://places.googleapis.com/v1/places/': () => ({ location: { latitude: 1, longitude: 2 } }),
    });
    const google = new GoogleMapsPort(KEY, fetcher);
    expect(await google.searchPlaces('a', 5)).toEqual([]);
    expect(calls).toHaveLength(0);
    expect(await google.searchPlaces('chợ', 1)).toHaveLength(1);
  });

  it('throws UnavailableMapsError on HTTP errors and when no detail resolves', async () => {
    const denied = new GoogleMapsPort(KEY, fakeFetch({}, 403).fetcher);
    await expect(denied.searchPlaces('chợ hàn', 5)).rejects.toBeInstanceOf(UnavailableMapsError);

    const noDetails = new GoogleMapsPort(
      KEY,
      fakeFetch({
        'https://places.googleapis.com/v1/places:autocomplete': () => AUTOCOMPLETE,
        'https://places.googleapis.com/v1/places/': () => ({}),
      }).fetcher,
    );
    await expect(noDetails.searchPlaces('chợ hàn', 5)).rejects.toBeInstanceOf(UnavailableMapsError);

    const network = new GoogleMapsPort(KEY, async () => {
      throw new Error('ECONNRESET');
    });
    await expect(network.routeDistanceKm(NEAR, NEAR)).rejects.toBeInstanceOf(UnavailableMapsError);
  });

  it('reverse geocodes with the Geocoding API (key as query param), keeping the fix', async () => {
    const { fetcher, calls } = fakeFetch({
      'https://maps.googleapis.com/maps/api/geocode/json': () => ({
        status: 'OK',
        results: [
          {
            formatted_address: '12 Bạch Đằng, Hải Châu, Đà Nẵng, Việt Nam',
            types: ['street_address'],
            geometry: { location: { lat: 16.07, lng: 108.22 } },
          },
        ],
      }),
    });
    const google = new GoogleMapsPort(KEY, fetcher);
    expect(await google.reverseGeocode(NEAR)).toEqual({
      lat: NEAR.lat,
      lng: NEAR.lng,
      name: '12 Bạch Đằng',
      address: '12 Bạch Đằng, Hải Châu, Đà Nẵng',
      provider: 'google',
      kind: 'address',
    });
    const url = new URL(calls[0].url);
    expect(url.searchParams.get('latlng')).toBe(`${NEAR.lat},${NEAR.lng}`);
    expect(url.searchParams.get('language')).toBe('vi');
    expect(calls[0].init.headers['X-Goog-Api-Key']).toBeUndefined();
  });

  it('reverse prefers the street address (with house number) over a bare street', async () => {
    const { fetcher } = fakeFetch({
      'https://maps.googleapis.com/maps/api/geocode/json': () => ({
        status: 'OK',
        results: [
          {
            formatted_address: 'Nguyễn Văn Linh, Hải Châu, Đà Nẵng, Việt Nam',
            types: ['route'],
            geometry: { location: { lat: 16.06, lng: 108.21 } },
          },
          {
            formatted_address: '3 Nguyễn Văn Linh, Hải Châu, Đà Nẵng, Việt Nam',
            types: ['street_address'],
            geometry: { location: { lat: 16.06, lng: 108.21 } },
          },
        ],
      }),
    });
    const place = await new GoogleMapsPort(KEY, fetcher).reverseGeocode(NEAR);
    expect(place?.name).toBe('3 Nguyễn Văn Linh');
    expect(place?.kind).toBe('address');
  });

  it('maps Geocoding statuses: ZERO_RESULTS → null, REQUEST_DENIED → unavailable', async () => {
    const zero = new GoogleMapsPort(
      KEY,
      fakeFetch({ 'https://maps.googleapis.com/': () => ({ status: 'ZERO_RESULTS', results: [] }) }).fetcher,
    );
    expect(await zero.reverseGeocode(NEAR)).toBeNull();
    const denied = new GoogleMapsPort(
      KEY,
      fakeFetch({ 'https://maps.googleapis.com/': () => ({ status: 'REQUEST_DENIED' }) }).fetcher,
    );
    await expect(denied.reverseGeocode(NEAR)).rejects.toBeInstanceOf(UnavailableMapsError);
    await expect(denied.geocode('Chợ Hàn')).rejects.toBeInstanceOf(UnavailableMapsError);
  });

  it('computes driving routes with the Routes API (Essentials, no traffic)', async () => {
    const { fetcher, calls } = fakeFetch({
      'https://routes.googleapis.com/directions/v2:computeRoutes': () => ({
        routes: [
          { distanceMeters: 5234, duration: '611s', description: 'Cầu Rồng', polyline: { encodedPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@' } },
        ],
      }),
    });
    const google = new GoogleMapsPort(KEY, fetcher);
    const [route] = await google.computeRoutes(NEAR, { lat: 16.06, lng: 108.24 });
    expect(route).toMatchObject({ distanceM: 5234, durationSec: 611, summary: 'Cầu Rồng' });
    expect(route.coords).toHaveLength(3);
    const body = JSON.parse(calls[0].init.body ?? '{}');
    expect(body).toMatchObject({ travelMode: 'DRIVE', routingPreference: 'TRAFFIC_UNAWARE', computeAlternativeRoutes: true });
    expect(calls[0].init.headers['X-Goog-FieldMask']).toContain('routes.polyline.encodedPolyline');

    expect(await google.routeDistanceKm(NEAR, { lat: 16.06, lng: 108.24 })).toBeCloseTo(5.234, 3);
    expect(JSON.parse(calls[1].init.body ?? '{}').computeAlternativeRoutes).toBe(false);
  });
});

describe('google-maps helpers', () => {
  it('decodes the reference encoded polyline', () => {
    expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@')).toEqual([
      [38.5, -120.2],
      [40.7, -120.95],
      [43.252, -126.453],
    ]);
  });

  it('parses durations, kinds and country suffixes', () => {
    expect(parseDurationSec('754s')).toBe(754);
    expect(parseDurationSec('12.6s')).toBe(13);
    expect(parseDurationSec(undefined)).toBe(0);
    expect(googleKind(['premise'])).toBe('address');
    expect(googleKind(['route'])).toBe('street');
    expect(googleKind(['restaurant', 'establishment'])).toBe('poi');
    expect(googleKind(['locality', 'political'])).toBe('area');
    expect(stripCountry('Hội An, Quảng Nam, Vietnam')).toBe('Hội An, Quảng Nam');
  });
});
