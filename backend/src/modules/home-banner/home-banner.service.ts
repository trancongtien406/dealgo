import { Inject, Injectable } from '@nestjs/common';
import { DocumentStoreService } from '../../platform/storage/document-store.service.js';
import {
  inferRegionCodeFromCoords,
  isKnownServiceRegionCode,
} from '../service-area/service-regions.js';
import { HOME_BANNER_REPOSITORY } from './home-banner.constants.js';
import type {
  CreateHomeBannerDto,
  HomeBannerEventDto,
  ListPublicHomeBannersQuery,
  PatchHomeBannerDto,
  UploadHomeBannerImageDto,
} from './home-banner.dto.js';
import {
  HOME_BANNER_IMAGE_TYPES,
  HOME_BANNER_STORAGE_PREFIX,
  homeBannerCtaView,
  homeBannerError,
  homeBannerImageKey,
  homeBannerImagePath,
  homeBannerStatDay,
  homeBannerState,
  isHomeBannerId,
  keyFromHomeBannerImageUrl,
  normalizeHomeBannerCta,
  resolveHomeBannerImagePayload,
  selectHomeBanners,
  type HomeBanner,
  type HomeBannerCta,
  type HomeBannerServiceScope,
  type HomeBannerState,
} from './home-banner.js';
import type {
  HomeBannerCounts,
  HomeBannerFields,
  HomeBannerRepository,
} from './home-banner.repository.js';

export type PublicHomeBannerView = {
  id: string;
  imageUrl: string;
  cta: HomeBannerCta | null;
  service: HomeBannerServiceScope;
};

export type OpsHomeBannerView = Omit<HomeBanner, 'startsAt' | 'endsAt' | 'createdAt' | 'updatedAt'> & {
  startsAt: string | null;
  endsAt: string | null;
  createdAt: string;
  updatedAt: string;
  state: HomeBannerState;
  stats: HomeBannerCounts & { ctr: number; last7d: HomeBannerCounts };
};

/** How long the public list is served from memory before re-reading the table. */
const PUBLIC_CACHE_MS = 30_000;
const NOT_FOUND = () => homeBannerError(404, 'HOME_BANNER_NOT_FOUND', 'Home banner not found');
const IMAGE_TYPE = () =>
  homeBannerError(415, 'UPLOAD_TYPE_NOT_ALLOWED', 'Banner image must be a JPEG, PNG or WebP image');

function parseDate(value: string | null | undefined): Date | null | undefined {
  if (value === undefined) {
    return undefined;
  }
  return value === null ? null : new Date(value);
}

function normalizeRegion(value: string | null | undefined): string | null | undefined {
  if (value === undefined) {
    return undefined;
  }
  const code = value?.trim().toUpperCase() || null;
  if (code && !isKnownServiceRegionCode(code)) {
    throw homeBannerError(400, 'HOME_BANNER_REGION_UNKNOWN', `Unknown service region ${code}`);
  }
  return code;
}

function toPublic(row: HomeBanner): PublicHomeBannerView {
  return {
    id: row.id,
    imageUrl: row.imageUrl!,
    cta: homeBannerCtaView(row.ctaUrl),
    service: row.service,
  };
}

@Injectable()
export class HomeBannerService {
  private cache: { at: number; rows: HomeBanner[] } | null = null;
  /** Overridable in specs. */
  clock: () => Date = () => new Date();

  constructor(
    @Inject(HOME_BANNER_REPOSITORY) private readonly banners: HomeBannerRepository,
    private readonly uploads: DocumentStoreService,
  ) {}

  // ---- public -----------------------------------------------------------

  async listPublic(query: ListPublicHomeBannersQuery): Promise<PublicHomeBannerView[]> {
    const region = query.region?.trim().toUpperCase() || inferRegionCodeFromCoords(query.lat, query.lng);
    const rows = await this.cachedRows();
    return selectHomeBanners(rows, {
      audience: query.role,
      service: query.service,
      regionCode: region ?? null,
      now: this.clock(),
    }).map(toPublic);
  }

  /** Counts impressions / clicks for live banners; unknown ids are ignored. */
  async recordEvents(events: readonly HomeBannerEventDto[]): Promise<{ accepted: number }> {
    const now = this.clock();
    const live = new Set(
      (await this.cachedRows()).filter((b) => homeBannerState(b, now) === 'LIVE').map((b) => b.id),
    );
    const counts = new Map<string, HomeBannerCounts>();
    let accepted = 0;
    for (const event of events) {
      if (!live.has(event.bannerId)) {
        continue;
      }
      const cur = counts.get(event.bannerId) ?? { impressions: 0, clicks: 0 };
      if (event.type === 'CLICK') {
        cur.clicks += 1;
      } else {
        cur.impressions += 1;
      }
      counts.set(event.bannerId, cur);
      accepted += 1;
    }
    if (counts.size > 0) {
      await this.banners.addStats(homeBannerStatDay(now), counts);
    }
    return { accepted };
  }

  async readImage(id: string, file: string): Promise<{ body: Buffer; contentType: string }> {
    const key = homeBannerImageKey(id, file);
    const current = key ? await this.banners.find(id) : null;
    if (!key || !current || current.imageUrl !== homeBannerImagePath(id, key)) {
      throw homeBannerError(404, 'HOME_BANNER_IMAGE_NOT_FOUND', 'Image not found');
    }
    const ext = file.slice(file.lastIndexOf('.') + 1);
    const found = await this.uploads.read({ key, contentType: ext === 'jpg' ? 'image/jpeg' : `image/${ext}` });
    if (!found) {
      throw homeBannerError(404, 'HOME_BANNER_IMAGE_NOT_FOUND', 'Image not found');
    }
    return found;
  }

  // ---- ops --------------------------------------------------------------

  async listOps(): Promise<OpsHomeBannerView[]> {
    const now = this.clock();
    const since = homeBannerStatDay(new Date(now.getTime() - 6 * 86_400_000));
    const [rows, totals] = await Promise.all([this.banners.list(), this.banners.totals(since)]);
    return rows.map((row) => this.toOps(row, now, totals.get(row.id)));
  }

  async create(input: CreateHomeBannerDto, actorUserId: string): Promise<OpsHomeBannerView> {
    const rows = await this.banners.list();
    const fields: HomeBannerFields = {
      imageUrl: null,
      ctaUrl: normalizeHomeBannerCta(input.ctaUrl, input.audiences),
      audiences: [...new Set(input.audiences)],
      service: input.service ?? 'ALL',
      regionCode: normalizeRegion(input.regionCode) ?? null,
      startsAt: parseDate(input.startsAt) ?? null,
      endsAt: parseDate(input.endsAt) ?? null,
      sortOrder: input.sortOrder ?? (rows.length ? Math.max(...rows.map((r) => r.sortOrder)) + 10 : 0),
      active: false,
    };
    if (input.active) {
      throw homeBannerError(400, 'HOME_BANNER_IMAGE_REQUIRED', 'Upload an image before activating the banner');
    }
    this.assertWindow(fields.startsAt, fields.endsAt);
    const saved = await this.banners.create(fields, actorUserId, {
      action: 'HOME_BANNER_CREATE',
      reason: input.reason?.trim() || 'Tạo banner trang chủ',
      metadata: { audiences: fields.audiences, service: fields.service },
    });
    this.invalidate();
    return this.toOps(saved, this.clock());
  }

  async update(id: string, patch: PatchHomeBannerDto, actorUserId: string): Promise<OpsHomeBannerView> {
    const current = await this.require(id);
    const next: Partial<HomeBannerFields> = {};
    if (patch.audiences !== undefined) next.audiences = [...new Set(patch.audiences)];
    if (patch.service !== undefined) next.service = patch.service;
    if (patch.regionCode !== undefined) next.regionCode = normalizeRegion(patch.regionCode) ?? null;
    if (patch.startsAt !== undefined) next.startsAt = parseDate(patch.startsAt) ?? null;
    if (patch.endsAt !== undefined) next.endsAt = parseDate(patch.endsAt) ?? null;
    if (patch.sortOrder !== undefined) next.sortOrder = patch.sortOrder;
    if (patch.active !== undefined) next.active = patch.active;
    const audiences = next.audiences ?? current.audiences;
    if (patch.ctaUrl !== undefined || patch.audiences !== undefined) {
      next.ctaUrl = normalizeHomeBannerCta(patch.ctaUrl !== undefined ? patch.ctaUrl : current.ctaUrl, audiences);
    }
    if ((next.active ?? current.active) && !current.imageUrl) {
      throw homeBannerError(400, 'HOME_BANNER_IMAGE_REQUIRED', 'Upload an image before activating the banner');
    }
    this.assertWindow(
      next.startsAt !== undefined ? next.startsAt : current.startsAt,
      next.endsAt !== undefined ? next.endsAt : current.endsAt,
    );
    const changes = diffBanner(current, next);
    if (Object.keys(changes).length === 0) {
      throw homeBannerError(400, 'VALIDATION_ERROR', 'No banner field to update');
    }
    const saved = await this.banners.update(id, next, actorUserId, {
      action: 'HOME_BANNER_UPDATE',
      reason: patch.reason?.trim() || 'Cập nhật banner trang chủ',
      metadata: { changes },
    });
    if (!saved) throw NOT_FOUND();
    this.invalidate();
    return this.toOps(saved, this.clock());
  }

  async remove(id: string, actorUserId: string): Promise<{ deleted: true }> {
    const current = await this.require(id);
    await this.banners.delete(id, actorUserId, {
      action: 'HOME_BANNER_DELETE',
      reason: 'Xoá banner trang chủ',
      metadata: { imageUrl: current.imageUrl },
    });
    const key = keyFromHomeBannerImageUrl(current.imageUrl);
    if (key) {
      await this.uploads.discard([{ key }]);
    }
    this.invalidate();
    return { deleted: true };
  }

  async reorder(ids: readonly string[], actorUserId: string): Promise<OpsHomeBannerView[]> {
    const unique = [...new Set(ids)];
    const known = new Set((await this.banners.list()).map((b) => b.id));
    const missing = unique.filter((id) => !known.has(id));
    if (missing.length > 0) {
      throw homeBannerError(404, 'HOME_BANNER_NOT_FOUND', `Unknown banner ids: ${missing.join(', ')}`);
    }
    await this.banners.reorder(unique, actorUserId, {
      action: 'HOME_BANNER_REORDER',
      reason: 'Sắp xếp banner trang chủ',
      metadata: { ids: unique },
    });
    this.invalidate();
    return this.listOps();
  }

  async uploadImage(id: string, input: UploadHomeBannerImageDto, actorUserId: string): Promise<OpsHomeBannerView> {
    const current = await this.require(id);
    const payload = resolveHomeBannerImagePayload(input);
    if (!payload) {
      throw homeBannerError(400, 'VALIDATION_ERROR', 'contentBase64 or dataUrl is required');
    }
    const declared = payload.contentType?.toLowerCase();
    const normalized = declared === 'image/jpg' ? 'image/jpeg' : declared;
    if (normalized && !(HOME_BANNER_IMAGE_TYPES as readonly string[]).includes(normalized)) {
      throw IMAGE_TYPE();
    }
    const previous = keyFromHomeBannerImageUrl(current.imageUrl);
    const saved = await this.uploads.storeThen(
      `${HOME_BANNER_STORAGE_PREFIX}/${id}`,
      [{ label: 'home-banner', contentType: payload.contentType, contentBase64: payload.base64 }],
      async ([ref]) => {
        if (!ref || !(HOME_BANNER_IMAGE_TYPES as readonly string[]).includes(ref.contentType)) {
          throw IMAGE_TYPE();
        }
        const imageUrl = homeBannerImagePath(id, ref.key);
        const updated = await this.banners.update(id, { imageUrl }, actorUserId, {
          action: 'HOME_BANNER_UPDATE',
          reason: 'Cập nhật ảnh banner',
          metadata: { changes: { imageUrl: { from: current.imageUrl, to: imageUrl } } },
        });
        if (!updated) throw NOT_FOUND();
        return updated;
      },
    );
    if (previous) {
      await this.uploads.discard([{ key: previous }]);
    }
    this.invalidate();
    return this.toOps(saved, this.clock());
  }

  // ---- helpers ----------------------------------------------------------

  private async require(id: string): Promise<HomeBanner> {
    const row = isHomeBannerId(id) ? await this.banners.find(id) : null;
    if (!row) throw NOT_FOUND();
    return row;
  }

  private assertWindow(startsAt: Date | null, endsAt: Date | null): void {
    if (startsAt && endsAt && endsAt.getTime() <= startsAt.getTime()) {
      throw homeBannerError(400, 'VALIDATION_ERROR', 'endsAt must be after startsAt');
    }
  }

  private async cachedRows(): Promise<HomeBanner[]> {
    const now = Date.now();
    if (!this.cache || now - this.cache.at > PUBLIC_CACHE_MS) {
      const rows = (await this.banners.list()).filter((b) => b.active && b.imageUrl);
      this.cache = { at: now, rows };
    }
    return this.cache.rows;
  }

  private invalidate(): void {
    this.cache = null;
  }

  private toOps(
    row: HomeBanner,
    now: Date,
    totals?: HomeBannerCounts & { recent: HomeBannerCounts },
  ): OpsHomeBannerView {
    const impressions = totals?.impressions ?? 0;
    const clicks = totals?.clicks ?? 0;
    return {
      ...row,
      startsAt: row.startsAt?.toISOString() ?? null,
      endsAt: row.endsAt?.toISOString() ?? null,
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
      state: homeBannerState(row, now),
      stats: {
        impressions,
        clicks,
        ctr: impressions > 0 ? Math.round((clicks / impressions) * 10_000) / 10_000 : 0,
        last7d: totals?.recent ?? { impressions: 0, clicks: 0 },
      },
    };
  }
}

function comparable(value: unknown): unknown {
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(String).sort((a, b) => a.localeCompare(b)).join(',');
  return value;
}

/** Fields that differ: `{ field: { from, to } }` for the ops audit log. */
export function diffBanner(
  current: HomeBanner,
  next: Partial<HomeBannerFields>,
): Record<string, { from: unknown; to: unknown }> {
  const changes: Record<string, { from: unknown; to: unknown }> = {};
  for (const [field, to] of Object.entries(next)) {
    const from = current[field as keyof HomeBanner];
    if (to !== undefined && comparable(from) !== comparable(to)) {
      changes[field] = { from: comparable(from), to: comparable(to) };
    }
  }
  return changes;
}
