import { describe, expect, it, vi } from 'vitest';
import type { PlatformSettingKey } from '../../platform/settings/platform-settings.catalog.js';
import type { GoogleMapsPort } from './google-maps.js';
import { MockMapsPort, UnavailableMapsError, type MapsPort } from './maps-port.js';
import { MapsProviderSettings, SwitchingMapsPort } from './maps-provider-settings.js';

const P = { lat: 16.05, lng: 108.2 };

function settings(values: Partial<Record<PlatformSettingKey, string>>) {
  return { getString: vi.fn(async (key: PlatformSettingKey) => values[key] ?? 'mapbox') };
}

function googleStub(overrides: Partial<MapsPort> = {}): GoogleMapsPort {
  return {
    geocode: vi.fn(async () => ({ lat: 1, lng: 1, label: 'G', provider: 'google' as const })),
    searchPlaces: vi.fn(async () => [{ lat: 1, lng: 1, name: 'G', address: 'G', provider: 'google' as const }]),
    reverseGeocode: vi.fn(async () => ({ lat: 1, lng: 1, name: 'G', address: 'G', provider: 'google' as const })),
    routeDistanceKm: vi.fn(async () => 42),
    ...overrides,
  } as unknown as GoogleMapsPort;
}

describe('MapsProviderSettings', () => {
  it('is mapbox for every capability without a Google key, whatever the admin stored', async () => {
    const sel = new MapsProviderSettings(settings({ MAPS_SEARCH_PROVIDER: 'google' }), null);
    expect(sel.googleConfigured()).toBe(false);
    expect(await sel.chosen('search')).toBe('google');
    expect(await sel.effective('search')).toBe('mapbox');
  });

  it('follows the per-capability setting when Google is configured; read errors mean mapbox', async () => {
    const sel = new MapsProviderSettings(
      settings({ MAPS_SEARCH_PROVIDER: 'google', MAPS_ROUTE_PROVIDER: 'mapbox' }),
      googleStub(),
    );
    expect(await sel.effective('search')).toBe('google');
    expect(await sel.effective('reverse')).toBe('mapbox');
    expect(await sel.effective('route')).toBe('mapbox');
    const broken = new MapsProviderSettings({ getString: async () => Promise.reject(new Error('db down')) }, googleStub());
    expect(await broken.effective('search')).toBe('mapbox');
  });
});

describe('SwitchingMapsPort', () => {
  it('delegates each capability to the chosen provider', async () => {
    const reverseGeocode = vi.fn(async () => null);
    const google = googleStub({ reverseGeocode });
    const port = new SwitchingMapsPort(
      new MockMapsPort(),
      new MapsProviderSettings(settings({ MAPS_SEARCH_PROVIDER: 'google', MAPS_ROUTE_PROVIDER: 'google' }), google),
    );
    expect((await port.searchPlaces('chợ hàn', 5, P))[0].provider).toBe('google');
    expect((await port.geocode('chợ hàn')).provider).toBe('google');
    expect((await port.reverseGeocode({ lat: 16.0682, lng: 108.2237 }))?.provider).toBe('mock');
    expect(await port.routeDistanceKm(P, P)).toBe(42);
    expect(reverseGeocode).not.toHaveBeenCalled();
  });

  it('falls back to the primary when Google is unavailable, but surfaces other errors', async () => {
    const google = googleStub({
      searchPlaces: vi.fn(async () => {
        throw new UnavailableMapsError('quota');
      }),
      reverseGeocode: vi.fn(async () => {
        throw new TypeError('bug');
      }),
    });
    const port = new SwitchingMapsPort(
      new MockMapsPort(),
      new MapsProviderSettings(settings({ MAPS_SEARCH_PROVIDER: 'google', MAPS_REVERSE_PROVIDER: 'google' }), google),
    );
    const items = await port.searchPlaces('Chợ Hàn', 5);
    expect(items[0].provider).toBe('mock');
    await expect(port.reverseGeocode(P)).rejects.toBeInstanceOf(TypeError);
  });

  it('never calls Google when it is not configured', async () => {
    const port = new SwitchingMapsPort(
      new MockMapsPort(),
      new MapsProviderSettings(settings({ MAPS_SEARCH_PROVIDER: 'google' }), null),
    );
    expect((await port.searchPlaces('Chợ Hàn', 5))[0].provider).toBe('mock');
  });
});
