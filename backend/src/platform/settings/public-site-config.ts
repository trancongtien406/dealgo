/**
 * Admin-managed public website links (PUBLIC_SITE_CONFIG). Every field is optional; an empty
 * field is dropped so the website never renders a fake or placeholder link. No secrets here.
 */
export type PublicSiteSocialKey =
  'facebook' | 'tiktok' | 'zalo' | 'youtube' | 'instagram';

export type PublicSiteConfig = {
  appStoreUrl?: string;
  googlePlayUrl?: string;
  socials?: Partial<Record<PublicSiteSocialKey, string>>;
  contactEmail?: string;
  hotline?: string;
  comingSoonCities?: string[];
};

const STORE_HOSTS = {
  appStoreUrl: ['apps.apple.com'],
  googlePlayUrl: ['play.google.com'],
} as const;

export const PUBLIC_SITE_SOCIAL_HOSTS: Record<
  PublicSiteSocialKey,
  readonly string[]
> = {
  facebook: ['facebook.com', 'www.facebook.com', 'm.facebook.com', 'fb.com'],
  tiktok: ['tiktok.com', 'www.tiktok.com'],
  zalo: ['zalo.me', 'oa.zalo.me'],
  youtube: ['youtube.com', 'www.youtube.com', 'youtu.be'],
  instagram: ['instagram.com', 'www.instagram.com'],
};

const SOCIAL_KEYS = Object.keys(
  PUBLIC_SITE_SOCIAL_HOSTS,
) as PublicSiteSocialKey[];
const TOP_KEYS = [
  'appStoreUrl',
  'googlePlayUrl',
  'socials',
  'contactEmail',
  'hotline',
  'comingSoonCities',
];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const HOTLINE_RE = /^\+?[0-9][0-9 .-]{5,18}$/;

export class PublicSiteConfigError extends Error {}

function blank(v: unknown): boolean {
  return (
    v === undefined || v === null || (typeof v === 'string' && v.trim() === '')
  );
}

function httpsUrl(field: string, v: unknown, hosts: readonly string[]): string {
  if (typeof v !== 'string' || v.length > 300) {
    throw new PublicSiteConfigError(`${field} must be a URL (max 300 chars)`);
  }
  let url: URL;
  try {
    url = new URL(v.trim());
  } catch {
    throw new PublicSiteConfigError(`${field} is not a valid URL`);
  }
  if (url.protocol !== 'https:' || url.username || url.password) {
    throw new PublicSiteConfigError(`${field} must use https`);
  }
  if (!hosts.includes(url.hostname.toLowerCase())) {
    throw new PublicSiteConfigError(
      `${field} host must be one of ${hosts.join(', ')}`,
    );
  }
  return url.toString();
}

/** Strict: throws PublicSiteConfigError on any invalid or unknown field. */
export function normalizePublicSiteConfig(input: unknown): PublicSiteConfig {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new PublicSiteConfigError('PUBLIC_SITE_CONFIG must be a JSON object');
  }
  const raw = input as Record<string, unknown>;
  for (const k of Object.keys(raw)) {
    if (!TOP_KEYS.includes(k))
      throw new PublicSiteConfigError(`Unknown field ${k}`);
  }
  const out: PublicSiteConfig = {};
  for (const k of ['appStoreUrl', 'googlePlayUrl'] as const) {
    if (!blank(raw[k])) out[k] = httpsUrl(k, raw[k], STORE_HOSTS[k]);
  }
  if (!blank(raw.socials)) {
    if (typeof raw.socials !== 'object' || Array.isArray(raw.socials)) {
      throw new PublicSiteConfigError('socials must be an object');
    }
    const s = raw.socials as Record<string, unknown>;
    const socials: Partial<Record<PublicSiteSocialKey, string>> = {};
    for (const k of Object.keys(s)) {
      if (!(SOCIAL_KEYS as string[]).includes(k))
        throw new PublicSiteConfigError(`Unknown social ${k}`);
      const key = k as PublicSiteSocialKey;
      if (!blank(s[key]))
        socials[key] = httpsUrl(
          `socials.${key}`,
          s[key],
          PUBLIC_SITE_SOCIAL_HOSTS[key],
        );
    }
    if (Object.keys(socials).length) out.socials = socials;
  }
  if (!blank(raw.contactEmail)) {
    const e = String(raw.contactEmail).trim();
    if (e.length > 120 || !EMAIL_RE.test(e))
      throw new PublicSiteConfigError('contactEmail is invalid');
    out.contactEmail = e.toLowerCase();
  }
  if (!blank(raw.hotline)) {
    const h = String(raw.hotline).trim();
    if (!HOTLINE_RE.test(h))
      throw new PublicSiteConfigError('hotline is invalid');
    out.hotline = h;
  }
  if (!blank(raw.comingSoonCities)) {
    const c = raw.comingSoonCities;
    if (!Array.isArray(c) || c.length > 10) {
      throw new PublicSiteConfigError(
        'comingSoonCities must be an array of at most 10 names',
      );
    }
    const cities = c
      .map((x) => (typeof x === 'string' ? x.trim() : ''))
      .filter(Boolean);
    if (cities.length !== c.length || cities.some((x) => x.length > 40)) {
      throw new PublicSiteConfigError('Each city name must be 1–40 characters');
    }
    if (cities.length) out.comingSoonCities = [...new Set(cities)];
  }
  return out;
}

/** Lenient read for the public endpoint: a broken stored value yields an empty config. */
export function readPublicSiteConfig(stored: unknown): PublicSiteConfig {
  try {
    return normalizePublicSiteConfig(stored);
  } catch {
    return {};
  }
}
