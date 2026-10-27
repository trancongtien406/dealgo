import { ConfigService } from '@nestjs/config';
import { describe, expect, it, vi } from 'vitest';
import type { GoogleMapsPort } from '../../integrations/maps/google-maps.js';
import { MapsProviderSettings } from '../../integrations/maps/maps-provider-settings.js';
import { parseDirections, RoutingService } from './routing.service.js';

const FROM = { lat: 16.0544, lng: 108.2022 };
const TO = { lat: 16.0592, lng: 108.2435 };

function service(env: Record<string, unknown>, body: unknown = { routes: [] }, ok = true) {
  const fetcher = vi.fn(async (_url: string) => ({ ok, status: ok ? 200 : 503, json: async () => body }));
  const config = new ConfigService(env);
  return { svc: new RoutingService(config as never, fetcher), fetcher };
}

const OSRM_BODY = {
  routes: [
    {
      geometry: { coordinates: [[108.2022, 16.0544], [108.22, 16.056], [108.2435, 16.0592]] },
      distance: 5234.4,
      duration: 611.7,
      legs: [{ summary: 'Cầu Rồng' }],
    },
    { geometry: { coordinates: [[108.2022]] }, distance: 1, duration: 1 },
  ],
};

describe('RoutingService (DEC-PROD-045)', () => {
  it('is unavailable without a configured provider and never calls out', async () => {
    for (const env of [{}, { ROUTING_PROVIDER: 'osrm' }, { ROUTING_PROVIDER: 'mapbox' }, { ROUTING_PROVIDER: 'x' }]) {
      const { svc, fetcher } = service(env);
      expect(await svc.route(FROM, TO)).toEqual({ provider: 'none', available: false, routes: [] });
      expect(fetcher).not.toHaveBeenCalled();
    }
  });

  it('queries the configured OSRM server, maps [lng,lat] → [lat,lng] and caches', async () => {
    const { svc, fetcher } = service(
      { ROUTING_PROVIDER: 'osrm', ROUTING_OSRM_URL: 'http://osrm.internal:5000/' },
      OSRM_BODY,
    );
    const first = await svc.route(FROM, TO);
    expect(first).toEqual({
      provider: 'osrm',
      available: true,
      routes: [
        {
          coords: [[16.0544, 108.2022], [16.056, 108.22], [16.0592, 108.2435]],
          distanceM: 5234,
          durationSec: 612,
          summary: 'Cầu Rồng',
        },
      ],
    });
    expect(fetcher.mock.calls[0]![0]).toMatch(
      /^http:\/\/osrm\.internal:5000\/route\/v1\/driving\/108\.2022,16\.0544;108\.2435,16\.0592\?/,
    );
    await svc.route(FROM, TO);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('keeps the Mapbox token server-side in the request URL and degrades on provider errors', async () => {
    const { svc, fetcher } = service(
      { ROUTING_PROVIDER: 'mapbox', MAPBOX_DIRECTIONS_TOKEN: 'pk.secret' },
      {},
      false,
    );
    expect(await svc.route(FROM, TO)).toEqual({ provider: 'mapbox', available: false, routes: [] });
    expect(fetcher.mock.calls[0]![0]).toContain('api.mapbox.com/directions/v5/mapbox/driving/');
    expect(fetcher.mock.calls[0]![0]).toContain('access_token=pk.secret');
  });

  it('uses Google routes when the admin chose Google, else falls back to the env provider', async () => {
    const config = new ConfigService({ ROUTING_PROVIDER: 'osrm', ROUTING_OSRM_URL: 'http://osrm.internal:5000' });
    const fetcher = vi.fn(async (_url: string) => ({ ok: true, status: 200, json: async () => OSRM_BODY }));
    const googleRoute = { coords: [[16.0544, 108.2022], [16.0592, 108.2435]] as [number, number][], distanceM: 5100, durationSec: 600, summary: '' };
    const computeRoutes = vi.fn(async () => [googleRoute]);
    let choice = 'google';
    const selector = new MapsProviderSettings(
      { getString: async () => choice },
      { computeRoutes } as unknown as GoogleMapsPort,
    );
    const svc = new RoutingService(config as never, fetcher, selector);
    expect(await svc.route(FROM, TO)).toEqual({ provider: 'google', available: true, routes: [googleRoute] });
    expect(fetcher).not.toHaveBeenCalled();

    computeRoutes.mockRejectedValueOnce(new Error('quota'));
    const other = { lat: 16.07, lng: 108.25 };
    expect((await svc.route(FROM, other)).provider).toBe('osrm');

    choice = 'mapbox';
    expect((await svc.route(TO, FROM)).provider).toBe('osrm');
    expect(computeRoutes).toHaveBeenCalledTimes(2);
  });

  it('ignores malformed provider payloads', () => {
    expect(parseDirections(null)).toEqual([]);
    expect(parseDirections({ routes: [{ geometry: { coordinates: [['a', 'b'], [1, 2]] } }] })).toEqual([]);
  });
});
