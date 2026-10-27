/**
 * Admin-managed home banners: pure rules (CTA allowlist, visibility, image paths).
 * No Nest / Prisma imports so specs and the repository can share them.
 */
import { HttpException } from '@nestjs/common';

export const HOME_BANNER_AUDIENCES = ['CUSTOMER', 'DRIVER', 'MERCHANT'] as const;
export type HomeBannerAudience = (typeof HOME_BANNER_AUDIENCES)[number];

export const HOME_BANNER_SERVICES = ['ALL', 'RIDE', 'FOOD'] as const;
export type HomeBannerServiceScope = (typeof HOME_BANNER_SERVICES)[number];

export const HOME_BANNER_EVENT_TYPES = ['IMPRESSION', 'CLICK'] as const;
export type HomeBannerEventType = (typeof HOME_BANNER_EVENT_TYPES)[number];

/** Banners returned to one home screen at most. */
export const HOME_BANNER_PUBLIC_LIMIT = 8;
/** Seconds clients / CDNs may cache the public list. */
export const HOME_BANNER_PUBLIC_MAX_AGE_S = 60;

export type HomeBanner = {
  id: string;
  /** 2:1 image-only art; any wording lives in the image itself. */
  imageUrl: string | null;
  ctaUrl: string | null;
  audiences: HomeBannerAudience[];
  service: HomeBannerServiceScope;
  regionCode: string | null;
  startsAt: Date | null;
  endsAt: Date | null;
  sortOrder: number;
  active: boolean;
  createdByUserId: string | null;
  updatedByUserId: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export type HomeBannerCta = { kind: 'app'; target: string } | { kind: 'web'; target: string };

export function homeBannerError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ errorCode, message }, status);
}

/**
 * In-app pages a banner may open, per shell. Landing pages only (no per-order or
 * per-ride pages); mirrors the mobile router (`deep_link_inventory_test.dart`).
 */
const APP_PATHS: Record<HomeBannerAudience, readonly RegExp[]> = {
  CUSTOMER: [
    /^\/customer$/,
    /^\/customer\/(book|shop|trips)$/,
    /^\/customer\/food\/stores\/[A-Za-z0-9_-]{1,64}$/,
    /^\/customer\/account\/(vouchers|notifications|help)$/,
  ],
  DRIVER: [/^\/driver$/, /^\/driver\/(jobs|earnings)$/, /^\/driver\/account\/(notifications|help)$/],
  MERCHANT: [
    /^\/merchant$/,
    /^\/merchant\/(orders|products)$/,
    /^\/merchant\/account\/(notifications|help)$/,
  ],
};

const QUERY_RE = /^[A-Za-z0-9_=&.-]{0,200}$/;

export function isAllowedAppPath(path: string, audience: HomeBannerAudience): boolean {
  return APP_PATHS[audience].some((re) => re.test(path));
}

/**
 * Validates and canonicalises a CTA. Accepts an in-app path (`/customer/shop`),
 * a `dealgo://customer/shop` link (stored as the path) or an `https://` URL.
 * An in-app path must be allowed for every targeted audience.
 * Returns null for an empty CTA; throws 400 `HOME_BANNER_CTA_NOT_ALLOWED` otherwise.
 */
export function normalizeHomeBannerCta(
  raw: string | null | undefined,
  audiences: readonly HomeBannerAudience[],
): string | null {
  const value = raw?.trim() ?? '';
  if (!value) {
    return null;
  }
  const reject = (why: string) =>
    homeBannerError(400, 'HOME_BANNER_CTA_NOT_ALLOWED', `CTA not allowed: ${why}`);
  if (/^https:\/\//i.test(value)) {
    let url: URL;
    try {
      url = new URL(value);
    } catch {
      throw reject('invalid https URL');
    }
    if (url.protocol !== 'https:' || !url.hostname.includes('.') || url.username || url.password) {
      throw reject('invalid https URL');
    }
    return url.toString();
  }
  let location = value;
  if (/^dealgo:\/\//i.test(value)) {
    const rest = value.slice('dealgo://'.length);
    location = `/${rest.startsWith('app/') ? rest.slice(4) : rest}`;
  }
  if (!location.startsWith('/')) {
    throw reject('use an in-app path (/customer/...), dealgo:// or https://');
  }
  const q = location.indexOf('?');
  const path = (q < 0 ? location : location.slice(0, q)).replace(/\/+/g, '/').replace(/\/$/, '') || '/';
  const query = q < 0 ? '' : location.slice(q + 1);
  if (!QUERY_RE.test(query)) {
    throw reject('query string');
  }
  if (audiences.length === 0) {
    throw reject('choose at least one audience');
  }
  const blocked = audiences.filter((a) => !isAllowedAppPath(path, a));
  if (blocked.length > 0) {
    throw reject(`${path} is not an allowlisted page for ${blocked.join(', ')}`);
  }
  return query ? `${path}?${query}` : path;
}

/** Public shape of a CTA: web links open in the in-app browser, app paths in the router. */
export function homeBannerCtaView(ctaUrl: string | null): HomeBannerCta | null {
  if (!ctaUrl) {
    return null;
  }
  return ctaUrl.startsWith('https://') ? { kind: 'web', target: ctaUrl } : { kind: 'app', target: ctaUrl };
}

export type HomeBannerState = 'LIVE' | 'SCHEDULED' | 'EXPIRED' | 'INACTIVE' | 'NO_IMAGE';

export function homeBannerState(banner: HomeBanner, now: Date): HomeBannerState {
  if (!banner.active) {
    return 'INACTIVE';
  }
  if (!banner.imageUrl) {
    return 'NO_IMAGE';
  }
  if (banner.startsAt && banner.startsAt.getTime() > now.getTime()) {
    return 'SCHEDULED';
  }
  if (banner.endsAt && banner.endsAt.getTime() <= now.getTime()) {
    return 'EXPIRED';
  }
  return 'LIVE';
}

export type HomeBannerQuery = {
  audience: HomeBannerAudience;
  /** RIDE / FOOD narrows to that service (plus ALL banners); omitted = every banner. */
  service?: HomeBannerServiceScope;
  /** Viewer's service region; null = unknown, only region-less banners are shown. */
  regionCode: string | null;
  now: Date;
};

export function compareHomeBanners(a: HomeBanner, b: HomeBanner): number {
  return a.sortOrder - b.sortOrder || a.createdAt.getTime() - b.createdAt.getTime() || a.id.localeCompare(b.id);
}

/** Banners one home screen should show, in display order. */
export function selectHomeBanners(rows: readonly HomeBanner[], query: HomeBannerQuery): HomeBanner[] {
  return rows
    .filter((b) => homeBannerState(b, query.now) === 'LIVE')
    .filter((b) => b.audiences.includes(query.audience))
    .filter((b) => !query.service || query.service === 'ALL' || b.service === 'ALL' || b.service === query.service)
    .filter((b) => b.regionCode === null || b.regionCode === query.regionCode)
    .sort(compareHomeBanners)
    .slice(0, HOME_BANNER_PUBLIC_LIMIT);
}

/** Calendar day (Asia/Ho_Chi_Minh, UTC+7) used to bucket impression / click counters. */
export function homeBannerStatDay(now: Date): string {
  return new Date(now.getTime() + 7 * 3_600_000).toISOString().slice(0, 10);
}

// ---- images -----------------------------------------------------------------

export const HOME_BANNER_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const HOME_BANNER_IMAGE_PREFIX = '/v1/public/home-banners/images';
export const HOME_BANNER_STORAGE_PREFIX = 'home-banners';

const ID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const FILE_RE = /^[0-9a-f-]{36}\.(jpg|png|webp)$/;

export function isHomeBannerId(id: string): boolean {
  return ID_RE.test(id);
}

export function homeBannerImagePath(id: string, key: string): string {
  const file = key.slice(`${HOME_BANNER_STORAGE_PREFIX}/${id}/`.length);
  return `${HOME_BANNER_IMAGE_PREFIX}/${id}/${file}`;
}

export function homeBannerImageKey(id: string, file: string): string | null {
  if (!ID_RE.test(id) || !FILE_RE.test(file)) {
    return null;
  }
  return `${HOME_BANNER_STORAGE_PREFIX}/${id}/${file}`;
}

export function keyFromHomeBannerImageUrl(url: string | null | undefined): string | null {
  if (!url?.startsWith(`${HOME_BANNER_IMAGE_PREFIX}/`)) {
    return null;
  }
  const [id, file, ...extra] = url.slice(HOME_BANNER_IMAGE_PREFIX.length + 1).split('/');
  if (!id || !file || extra.length > 0) {
    return null;
  }
  return homeBannerImageKey(id, file);
}

export function resolveHomeBannerImagePayload(input: {
  contentBase64?: string;
  dataUrl?: string;
  contentType?: string;
}): { base64: string; contentType?: string } | null {
  if (typeof input.dataUrl === 'string' && input.dataUrl.trim()) {
    const match = /^data:([^;,]+)?;base64,(.+)$/i.exec(input.dataUrl.trim());
    return match ? { contentType: match[1] || input.contentType, base64: match[2]! } : null;
  }
  if (typeof input.contentBase64 === 'string' && input.contentBase64.trim()) {
    return { contentType: input.contentType, base64: input.contentBase64.trim() };
  }
  return null;
}
