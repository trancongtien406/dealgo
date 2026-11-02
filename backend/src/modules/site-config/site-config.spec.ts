import { describe, expect, it } from 'vitest';
import {
  normalizePublicSiteConfig,
  readPublicSiteConfig,
} from '../../platform/settings/public-site-config.js';

describe('PUBLIC_SITE_CONFIG validation', () => {
  it('keeps valid https links and drops empty ones', () => {
    expect(
      normalizePublicSiteConfig({
        appStoreUrl: 'https://apps.apple.com/vn/app/dealgo/id1',
        googlePlayUrl: '',
        socials: { facebook: 'https://www.facebook.com/dealgo', tiktok: ' ' },
        contactEmail: 'Hi@DealGo.vn',
        hotline: '',
        comingSoonCities: ['Huế', 'Huế'],
      }),
    ).toEqual({
      appStoreUrl: 'https://apps.apple.com/vn/app/dealgo/id1',
      socials: { facebook: 'https://www.facebook.com/dealgo' },
      contactEmail: 'hi@dealgo.vn',
      comingSoonCities: ['Huế'],
    });
  });

  it.each([
    [{ appStoreUrl: 'http://apps.apple.com/x' }],
    [{ appStoreUrl: 'https://evil.example/x' }],
    [{ googlePlayUrl: 'javascript:alert(1)' }],
    [{ socials: { zalo: 'https://zalo.me.evil.com/x' } }],
    [{ socials: { twitter: 'https://x.com/a' } }],
    [{ socials: { messenger: 'https://www.facebook.com/dealgo' } }],
    [{ hotline: 'call me' }],
    [{ extra: 1 }],
  ])('rejects %j', (input) => {
    expect(() => normalizePublicSiteConfig(input)).toThrow();
  });

  it('accepts a Messenger chat link', () => {
    expect(
      normalizePublicSiteConfig({ socials: { messenger: 'https://m.me/dealgo' } }),
    ).toEqual({ socials: { messenger: 'https://m.me/dealgo' } });
  });

  it('reads a broken stored value as empty', () => {
    expect(readPublicSiteConfig({ appStoreUrl: 'nope' })).toEqual({});
  });
});
