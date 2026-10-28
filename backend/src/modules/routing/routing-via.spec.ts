import { ConfigService } from '@nestjs/config';
import { describe, expect, it, vi } from 'vitest';
import { RoutingService } from './routing.service.js';
import { toRouteGeometryView } from './route-geometry.js';

const A = { lat: 16.0544, lng: 108.2022 };
const B = { lat: 16.06, lng: 108.22 };
const C = { lat: 16.0592, lng: 108.2435 };

const BODY = {
  routes: [
    {
      geometry: { coordinates: [[108.2022, 16.0544], [108.22, 16.06], [108.2435, 16.0592]] },
      distance: 6000.4,
      duration: 700.2,
      legs: [
        { summary: 'a', distance: 2500.2, duration: 300.4 },
        { summary: 'b', distance: 3500.2, duration: 399.8 },
      ],
    },
  ],
};

function service(env: Record<string, unknown>) {
  const fetcher = vi.fn(async (_url: string) => ({ ok: true, status: 200, json: async () => BODY }));
  return { svc: new RoutingService(new ConfigService(env) as never, fetcher), fetcher };
}

describe('RoutingService.routeVia (multi-stop)', () => {
  it('sends every waypoint in order to Mapbox with the server token and returns legs', async () => {
    const { svc, fetcher } = service({ ROUTING_PROVIDER: 'mapbox', MAPBOX_DIRECTIONS_TOKEN: 'srv-token' });
    const lookup = await svc.routeVia([A, B, C]);
    const url = fetcher.mock.calls[0]![0];
    expect(url).toContain('/directions/v5/mapbox/driving/108.2022,16.0544;108.22,16.06;108.2435,16.0592?');
    expect(url).toContain('alternatives=false');
    expect(url).toContain('access_token=srv-token');
    expect(lookup.available).toBe(true);
    const view = toRouteGeometryView(lookup);
    expect(view.distanceM).toBe(6000);
    expect(view.legs).toEqual([
      { distanceM: 2500, durationSec: 300 },
      { distanceM: 3500, durationSec: 400 },
    ]);
    // Cached per waypoint list.
    await svc.routeVia([A, B, C]);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('two points behave like route(); no provider → unavailable without calling out', async () => {
    const { svc, fetcher } = service({});
    expect((await svc.routeVia([A, B, C])).available).toBe(false);
    expect((await svc.routeVia([A, C])).available).toBe(false);
    expect(fetcher).not.toHaveBeenCalled();
  });
});
