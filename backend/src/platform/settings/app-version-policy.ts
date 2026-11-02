/**
 * t82u / DEC-PROD-089 (AGENT_PROPOSED): admin-controlled app update policy (APP_VERSION_POLICY).
 * Per platform: builds below `minBuild` are blocked ("Cập nhật bắt buộc"), builds below
 * `latestBuild` get a dismissible prompt. 0 disables each rule (default).
 */
export const APP_PLATFORMS = ['ios', 'android'] as const;
export type AppPlatform = (typeof APP_PLATFORMS)[number];

export type AppPlatformPolicy = {
  minBuild: number;
  latestBuild: number;
  /** Display only, e.g. "1.2.0". */
  latestVersion: string;
  storeUrl: string;
};

export type AppVersionPolicy = Record<AppPlatform, AppPlatformPolicy> & {
  /** Optional Vietnamese copy shown on the update screens ('' = app default). */
  message: string;
  /** Reject API calls carrying X-App-Build below minBuild with APP_UPDATE_REQUIRED (426). */
  enforceApi: boolean;
};

export type AppUpdateVerdict = 'NONE' | 'OPTIONAL' | 'REQUIRED';

export class AppVersionPolicyError extends Error {}

const STORE_HOSTS: Record<AppPlatform, readonly string[]> = {
  ios: ['apps.apple.com', 'itunes.apple.com', 'testflight.apple.com'],
  android: ['play.google.com'],
};

const EMPTY_PLATFORM: AppPlatformPolicy = { minBuild: 0, latestBuild: 0, latestVersion: '', storeUrl: '' };

export const APP_VERSION_POLICY_DEFAULT: AppVersionPolicy = {
  ios: { ...EMPTY_PLATFORM },
  android: { ...EMPTY_PLATFORM },
  message: '',
  enforceApi: true,
};

function build(field: string, v: unknown): number {
  if (v === undefined || v === null || v === '') return 0;
  const n = typeof v === 'string' ? Number(v) : v;
  if (typeof n !== 'number' || !Number.isSafeInteger(n) || n < 0 || n > 1_000_000_000) {
    throw new AppVersionPolicyError(`${field} must be a whole number ≥ 0`);
  }
  return n;
}

function storeUrl(platform: AppPlatform, v: unknown): string {
  if (v === undefined || v === null || (typeof v === 'string' && v.trim() === '')) return '';
  if (typeof v !== 'string' || v.length > 300) {
    throw new AppVersionPolicyError(`${platform}.storeUrl must be a URL (max 300 chars)`);
  }
  let url: URL;
  try {
    url = new URL(v.trim());
  } catch {
    throw new AppVersionPolicyError(`${platform}.storeUrl must be a URL`);
  }
  if (url.protocol !== 'https:' || !STORE_HOSTS[platform].includes(url.hostname)) {
    throw new AppVersionPolicyError(`${platform}.storeUrl must be https on ${STORE_HOSTS[platform].join(' / ')}`);
  }
  return url.toString();
}

function platformPolicy(platform: AppPlatform, raw: unknown): AppPlatformPolicy {
  if (raw === undefined || raw === null) return { ...EMPTY_PLATFORM };
  if (typeof raw !== 'object' || Array.isArray(raw)) {
    throw new AppVersionPolicyError(`${platform} must be an object`);
  }
  const r = raw as Record<string, unknown>;
  const minBuild = build(`${platform}.minBuild`, r.minBuild);
  const latestBuild = build(`${platform}.latestBuild`, r.latestBuild);
  if (latestBuild > 0 && minBuild > latestBuild) {
    throw new AppVersionPolicyError(`${platform}.minBuild cannot exceed latestBuild`);
  }
  const latestVersion = typeof r.latestVersion === 'string' ? r.latestVersion.trim().slice(0, 40) : '';
  const url = storeUrl(platform, r.storeUrl);
  if (minBuild > 0 && !url) {
    throw new AppVersionPolicyError(`${platform}.storeUrl is required when minBuild is set`);
  }
  return { minBuild, latestBuild, latestVersion, storeUrl: url };
}

export function normalizeAppVersionPolicy(raw: unknown): AppVersionPolicy {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new AppVersionPolicyError('APP_VERSION_POLICY must be a JSON object');
  }
  const r = raw as Record<string, unknown>;
  const message = typeof r.message === 'string' ? r.message.trim() : '';
  if (message.length > 300) throw new AppVersionPolicyError('message max 300 chars');
  return {
    ios: platformPolicy('ios', r.ios),
    android: platformPolicy('android', r.android),
    message,
    enforceApi: r.enforceApi === undefined ? true : r.enforceApi === true,
  };
}

/** Lenient read for runtime use: a bad stored value never blocks anyone. */
export function readAppVersionPolicy(raw: unknown): AppVersionPolicy {
  try {
    return normalizeAppVersionPolicy(raw);
  } catch {
    return APP_VERSION_POLICY_DEFAULT;
  }
}

export function parseAppPlatform(v: unknown): AppPlatform | null {
  const s = typeof v === 'string' ? v.trim().toLowerCase() : '';
  return (APP_PLATFORMS as readonly string[]).includes(s) ? (s as AppPlatform) : null;
}

export function parseAppBuild(v: unknown): number | null {
  const s = typeof v === 'string' ? v.trim() : '';
  if (!/^\d{1,9}$/.test(s)) return null;
  return Number(s);
}

export function appUpdateVerdict(policy: AppVersionPolicy, platform: AppPlatform, buildNumber: number): AppUpdateVerdict {
  const p = policy[platform];
  if (p.minBuild > 0 && buildNumber < p.minBuild) return 'REQUIRED';
  if (p.latestBuild > 0 && buildNumber < p.latestBuild) return 'OPTIONAL';
  return 'NONE';
}
