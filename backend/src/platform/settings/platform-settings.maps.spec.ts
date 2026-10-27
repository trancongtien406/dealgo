import { ConfigService } from '@nestjs/config';
import { describe, expect, it } from 'vitest';
import { MemoryPlatformSettingsRepository } from './platform-settings.repository.js';
import { PlatformSettingsService } from './platform-settings.service.js';

const ACTOR = '00000000-0000-4000-8000-000000000001';

function service(env: Record<string, unknown>) {
  return new PlatformSettingsService(new MemoryPlatformSettingsRepository(), new ConfigService(env) as never);
}

describe('MAPS_*_PROVIDER settings', () => {
  it('seed to mapbox in the SUPPORT category', async () => {
    const views = (await service({}).list()).filter((v) => v.key.startsWith('MAPS_'));
    expect(views.map((v) => [v.key, v.value])).toEqual([
      ['MAPS_SEARCH_PROVIDER', 'mapbox'],
      ['MAPS_REVERSE_PROVIDER', 'mapbox'],
      ['MAPS_ROUTE_PROVIDER', 'mapbox'],
    ]);
    const support = await service({}).list({ category: 'SUPPORT', source: 'ALL' });
    expect(support.some((v) => v.key === 'MAPS_ROUTE_PROVIDER')).toBe(true);
  });

  it('accept only mapbox or google, and google only with GOOGLE_MAPS_API_KEY', async () => {
    const noKey = service({});
    await expect(noKey.patch('MAPS_SEARCH_PROVIDER', 'here', 'thử nhà cung cấp', ACTOR)).rejects.toMatchObject({
      errorCode: 'PLATFORM_SETTING_INVALID',
    });
    await expect(noKey.patch('MAPS_SEARCH_PROVIDER', 'google', 'chuyển sang Google', ACTOR)).rejects.toMatchObject({
      errorCode: 'MAPS_PROVIDER_NOT_CONFIGURED',
    });

    const withKey = service({ GOOGLE_MAPS_API_KEY: 'k' });
    const view = await withKey.patch('MAPS_SEARCH_PROVIDER', ' Google ', 'chuyển sang Google', ACTOR);
    expect(view.value).toBe('google');
    expect(await withKey.getString('MAPS_SEARCH_PROVIDER')).toBe('google');
  });
});
