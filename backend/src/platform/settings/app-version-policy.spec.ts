import {
  APP_VERSION_POLICY_DEFAULT,
  appUpdateVerdict,
  normalizeAppVersionPolicy,
  parseAppBuild,
  parseAppPlatform,
  readAppVersionPolicy,
} from './app-version-policy.js';

describe('APP_VERSION_POLICY (t82u)', () => {
  it('default blocks and nags nobody', () => {
    const p = normalizeAppVersionPolicy(APP_VERSION_POLICY_DEFAULT);
    expect(appUpdateVerdict(p, 'ios', 1)).toBe('NONE');
    expect(appUpdateVerdict(p, 'android', 0)).toBe('NONE');
  });

  it('REQUIRED below min, OPTIONAL below latest, NONE otherwise', () => {
    const p = normalizeAppVersionPolicy({
      ios: { minBuild: 20, latestBuild: 24, latestVersion: '1.0.1', storeUrl: 'https://apps.apple.com/app/id1' },
    });
    expect(appUpdateVerdict(p, 'ios', 19)).toBe('REQUIRED');
    expect(appUpdateVerdict(p, 'ios', 23)).toBe('OPTIONAL');
    expect(appUpdateVerdict(p, 'ios', 24)).toBe('NONE');
    expect(appUpdateVerdict(p, 'android', 1)).toBe('NONE');
    expect(p.enforceApi).toBe(true);
  });

  it.each([
    [{ ios: { minBuild: -1 } }, /whole number/],
    [{ ios: { minBuild: 5, latestBuild: 3, storeUrl: 'https://apps.apple.com/x' } }, /exceed/],
    [{ ios: { minBuild: 5 } }, /storeUrl is required/],
    [{ android: { minBuild: 5, storeUrl: 'https://evil.example/app' } }, /play.google.com/],
    [{ ios: { storeUrl: 'http://apps.apple.com/x' } }, /https/],
    [[], /object/],
  ])('rejects %j', (raw, msg) => {
    expect(() => normalizeAppVersionPolicy(raw)).toThrow(msg);
  });

  it('lenient read falls back to default', () => {
    expect(readAppVersionPolicy('nope')).toEqual(APP_VERSION_POLICY_DEFAULT);
  });

  it('parses headers', () => {
    expect(parseAppPlatform(' iOS ')).toBe('ios');
    expect(parseAppPlatform('web')).toBeNull();
    expect(parseAppBuild('23')).toBe(23);
    expect(parseAppBuild('1.0')).toBeNull();
    expect(parseAppBuild(undefined)).toBeNull();
  });
});
