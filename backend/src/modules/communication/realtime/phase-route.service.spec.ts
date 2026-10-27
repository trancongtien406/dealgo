import { describe, expect, it, vi } from 'vitest';
import { distanceToPolylineM } from '../../routing/route-phase.js';
import { PhaseRouteCache } from '../../routing/phase-route-cache.js';
import { PhaseRouteService } from './phase-route.service.js';

const rideId = '11111111-1111-4111-8111-111111111111';
const PICKUP = { lat: 16.0544, lng: 108.2022 };
const DROPOFF = { lat: 16.0439, lng: 108.1994 };
const COORDS: [number, number][] = [[16.06, 108.21], [16.0544, 108.2022]];

function setup(phase: 'APPROACH' | 'TRIP' = 'APPROACH', available = true, settings?: unknown) {
  const emitRouteUpdated = vi.fn();
  const rides = { routeLegsForDriver: vi.fn().mockResolvedValue({ phase, pickup: PICKUP, dropoff: DROPOFF }) };
  const food = { routeLegsForDriver: vi.fn().mockResolvedValue(null) };
  const routing = {
    provider: () => 'mapbox',
    route: vi.fn().mockResolvedValue(
      available
        ? { provider: 'mapbox', available: true, routes: [{ coords: COORDS, distanceM: 900, durationSec: 180 }] }
        : { provider: 'mapbox', available: false, routes: [] },
    ),
  };
  const cache = new PhaseRouteCache();
  const svc = new PhaseRouteService(rides as never, food as never, routing as never, { emitRouteUpdated } as never, cache, settings as never);
  return { svc, emitRouteUpdated, routing, rides, cache };
}

const fix = (lat: number, lng: number, sec: number) => ({ driverId: 'd1', lat, lng, at: new Date(sec * 1000) });

describe('PhaseRouteService', () => {
  it('APPROACH: first fix routes driver → pickup and pushes routeUpdated', async () => {
    const { svc, emitRouteUpdated, routing } = setup();
    await svc.onFix(fix(16.06, 108.21, 0), [rideId], []);
    expect(routing.route).toHaveBeenCalledWith({ lat: 16.06, lng: 108.21 }, PICKUP);
    expect(emitRouteUpdated).toHaveBeenCalledWith(
      expect.objectContaining({ aggregateType: 'Ride', aggregateId: rideId, phase: 'APPROACH', reason: 'INITIAL' }),
    );
    expect(emitRouteUpdated.mock.calls[0][0].route.coords).toEqual(COORDS);
  });

  it('throttles: on-route fixes and early off-route fixes do not call Directions', async () => {
    const { svc, routing } = setup();
    await svc.onFix(fix(16.06, 108.21, 0), [rideId], []);
    await svc.onFix(fix(16.07, 108.23, 60), [rideId], []); // off-route but < 120 s since last call
    await svc.onFix(fix(16.058, 108.207, 600), [rideId], []); // on the line, much later
    expect(routing.route).toHaveBeenCalledTimes(1);
  });

  it('no periodic refresh: a driver on the cached leg never triggers another lookup', async () => {
    const { svc, routing } = setup();
    for (let sec = 0; sec <= 1800; sec += 5) {
      await svc.onFix(fix(16.058, 108.207, sec), [rideId], []);
    }
    expect(routing.route).toHaveBeenCalledTimes(1);
  });

  it('re-routes when > 150 m off the leg after the 120 s throttle (defaults)', async () => {
    const { svc, routing, emitRouteUpdated } = setup();
    await svc.onFix(fix(16.06, 108.21, 0), [rideId], []);
    await svc.onFix(fix(16.07, 108.23, 125), [rideId], []);
    expect(routing.route).toHaveBeenCalledTimes(2);
    expect(emitRouteUpdated.mock.calls[1][0].reason).toBe('OFF_ROUTE');
  });

  it('throttle + threshold come from admin settings', async () => {
    const settings = {
      getNumber: vi.fn(async (key: string): Promise<number> => (key === 'ROUTE_REROUTE_MIN_INTERVAL_SECONDS' ? 30 : 5000)),
    };
    const { svc, routing } = setup('APPROACH', true, settings);
    await svc.onFix(fix(16.06, 108.21, 0), [rideId], []);
    await svc.onFix(fix(16.07, 108.23, 40), [rideId], []); // ~2.3 km off but threshold is 5 km
    expect(routing.route).toHaveBeenCalledTimes(1);
    settings.getNumber.mockImplementation(async (key: string) => (key === 'ROUTE_REROUTE_MIN_INTERVAL_SECONDS' ? 30 : 100));
    await svc.onFix(fix(16.07, 108.23, 80), [rideId], []);
    expect(routing.route).toHaveBeenCalledTimes(2);
  });

  it('phase change APPROACH → TRIP looks up once more; the cache is shared with REST', async () => {
    const { svc, routing, rides, cache } = setup();
    await svc.onFix(fix(16.06, 108.21, 0), [rideId], []);
    expect(cache.forPhase('Ride', rideId, 'APPROACH', 0)?.route.coords).toEqual(COORDS);
    rides.routeLegsForDriver.mockResolvedValue({ phase: 'TRIP', pickup: PICKUP, dropoff: DROPOFF });
    await svc.onFix(fix(16.0544, 108.2022, 10), [rideId], []);
    expect(routing.route).toHaveBeenCalledTimes(2);
    expect(routing.route).toHaveBeenLastCalledWith(PICKUP, DROPOFF);
    expect(cache.forPhase('Ride', rideId, 'APPROACH', 10_000)).toBeNull();
  });

  it('TRIP: initial leg is pickup → dropoff; unavailable route pushes empty coords (no straight line)', async () => {
    const { svc, routing, emitRouteUpdated } = setup('TRIP', false);
    await svc.onFix(fix(16.05, 108.2, 0), [rideId], []);
    expect(routing.route).toHaveBeenCalledWith(PICKUP, DROPOFF);
    expect(emitRouteUpdated.mock.calls[0][0].route).toMatchObject({ available: false, coords: [] });
  });

  it('distanceToPolylineM measures segment distance in metres', () => {
    expect(distanceToPolylineM({ lat: 16.0544, lng: 108.2022 }, COORDS)).toBeLessThan(1);
    expect(distanceToPolylineM({ lat: 16.07, lng: 108.23 }, COORDS)).toBeGreaterThan(1000);
  });
});
