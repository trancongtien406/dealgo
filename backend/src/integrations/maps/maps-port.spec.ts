import { haversineKm } from '../../modules/ride/ride-geo.js';
import {
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
