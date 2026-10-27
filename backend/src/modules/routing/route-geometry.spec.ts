import { describe, expect, it } from 'vitest';
import { toRouteGeometryView, UNAVAILABLE_ROUTE_GEOMETRY } from './route-geometry.js';
import type { RouteLookup } from './routing.service.js';

describe('toRouteGeometryView', () => {
  it('maps the best road option for mobile clients', () => {
    const lookup: RouteLookup = {
      provider: 'osrm',
      available: true,
      routes: [
        {
          coords: [
            [16.0544, 108.2022],
            [16.055, 108.21],
            [16.0592, 108.2435],
          ],
          distanceM: 4200,
          durationSec: 600,
          summary: 'Nguyen Van Linh',
        },
      ],
    };
    expect(toRouteGeometryView(lookup)).toEqual({
      available: true,
      provider: 'osrm',
      coords: [
        [16.0544, 108.2022],
        [16.055, 108.21],
        [16.0592, 108.2435],
      ],
      distanceM: 4200,
      durationSec: 600,
    });
  });

  it('falls back when the provider is unavailable', () => {
    expect(
      toRouteGeometryView({ provider: 'none', available: false, routes: [] }),
    ).toEqual(UNAVAILABLE_ROUTE_GEOMETRY);
  });
});
