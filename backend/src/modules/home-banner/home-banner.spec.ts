import { describe, expect, it } from 'vitest';
import {
  homeBannerCtaView,
  homeBannerStatDay,
  homeBannerState,
  keyFromHomeBannerImageUrl,
  normalizeHomeBannerCta,
  selectHomeBanners,
  type HomeBanner,
} from './home-banner.js';
import { MemoryHomeBannerRepository } from './home-banner.repository.js';
import { HomeBannerService } from './home-banner.service.js';

const NOW = new Date('2026-10-27T03:00:00.000Z');

function banner(overrides: Partial<HomeBanner> = {}): HomeBanner {
  return {
    id: overrides.id ?? '00000000-0000-4000-8000-000000000001',
    imageUrl: '/v1/public/home-banners/images/x/y.png',
    ctaUrl: null,
    audiences: ['CUSTOMER'],
    service: 'ALL',
    regionCode: null,
    startsAt: null,
    endsAt: null,
    sortOrder: 0,
    active: true,
    createdByUserId: null,
    updatedByUserId: null,
    createdAt: new Date('2026-10-01T00:00:00Z'),
    updatedAt: new Date('2026-10-01T00:00:00Z'),
    ...overrides,
  };
}

function makeService() {
  const repo = new MemoryHomeBannerRepository();
  const stored = new Map<string, Buffer>();
  let n = 0;
  const uploads = {
    storeThen: async (
      prefix: string,
      files: Array<{ contentType?: string; contentBase64: string }>,
      fn: (refs: Array<{ key: string; contentType: string }>) => Promise<unknown>,
    ) => {
      n += 1;
      const key = `${prefix}/00000000-0000-4000-8000-${String(n).padStart(12, '0')}.png`;
      stored.set(key, Buffer.from(files[0]!.contentBase64, 'base64'));
      return fn([{ key, contentType: files[0]!.contentType ?? 'image/png' }]);
    },
    discard: async (refs: Array<{ key: string }>) => {
      for (const ref of refs) stored.delete(ref.key);
    },
    read: async ({ key, contentType }: { key: string; contentType: string }) => {
      const body = stored.get(key);
      return body ? { body, contentType } : null;
    },
  } as never;
  const service = new HomeBannerService(repo, uploads);
  service.clock = () => NOW;
  return { repo, service, stored };
}

const PNG = Buffer.from('89504e470d0a1a0a0000', 'hex').toString('base64');

describe('normalizeHomeBannerCta', () => {
  it('accepts allowlisted in-app paths and dealgo:// links', () => {
    expect(normalizeHomeBannerCta('/customer/shop', ['CUSTOMER'])).toBe('/customer/shop');
    expect(normalizeHomeBannerCta('dealgo://customer/account/vouchers', ['CUSTOMER'])).toBe(
      '/customer/account/vouchers',
    );
    expect(normalizeHomeBannerCta('dealgo://app/driver/earnings', ['DRIVER'])).toBe('/driver/earnings');
    expect(normalizeHomeBannerCta('/customer/food/stores/abc-1', ['CUSTOMER'])).toBe('/customer/food/stores/abc-1');
    expect(normalizeHomeBannerCta('  ', ['CUSTOMER'])).toBeNull();
  });

  it('accepts https and rejects other schemes', () => {
    expect(normalizeHomeBannerCta('https://dealgo.vn/khuyen-mai', ['CUSTOMER'])).toBe('https://dealgo.vn/khuyen-mai');
    expect(() => normalizeHomeBannerCta('http://dealgo.vn', ['CUSTOMER'])).toThrow(/CTA not allowed/);
    expect(() => normalizeHomeBannerCta('javascript:alert(1)', ['CUSTOMER'])).toThrow(/CTA not allowed/);
    expect(() => normalizeHomeBannerCta('https://user:pw@evil.com', ['CUSTOMER'])).toThrow();
  });

  it('rejects pages outside the allowlist or another role shell', () => {
    expect(() => normalizeHomeBannerCta('/customer/ride/tracking/r1', ['CUSTOMER'])).toThrow();
    expect(() => normalizeHomeBannerCta('/customer/shop', ['CUSTOMER', 'DRIVER'])).toThrow(/DRIVER/);
    expect(() => normalizeHomeBannerCta('/customer/shop?x=<script>', ['CUSTOMER'])).toThrow();
  });

  it('exposes web vs app CTA kinds', () => {
    expect(homeBannerCtaView('https://a.vn')).toEqual({ kind: 'web', target: 'https://a.vn' });
    expect(homeBannerCtaView('/customer/shop')).toEqual({ kind: 'app', target: '/customer/shop' });
    expect(homeBannerCtaView(null)).toBeNull();
  });
});

describe('selectHomeBanners', () => {
  const rows = [
    banner({ id: 'a', sortOrder: 20 }),
    banner({ id: 'b', sortOrder: 10, service: 'FOOD' }),
    banner({ id: 'c', regionCode: 'HCM' }),
    banner({ id: 'd', audiences: ['DRIVER'] }),
    banner({ id: 'e', active: false }),
    banner({ id: 'f', imageUrl: null }),
    banner({ id: 'g', startsAt: new Date('2026-11-01T00:00:00Z') }),
    banner({ id: 'h', endsAt: NOW }),
  ];

  it('filters role, schedule, image and region, ordered by sortOrder', () => {
    const ids = selectHomeBanners(rows, { audience: 'CUSTOMER', regionCode: 'DN', now: NOW }).map((b) => b.id);
    expect(ids).toEqual(['b', 'a']);
    const hcm = selectHomeBanners(rows, { audience: 'CUSTOMER', regionCode: 'HCM', now: NOW }).map((b) => b.id);
    expect(hcm).toEqual(['c', 'b', 'a']);
    expect(selectHomeBanners(rows, { audience: 'DRIVER', regionCode: null, now: NOW }).map((b) => b.id)).toEqual(['d']);
  });

  it('narrows by service keeping ALL banners', () => {
    const ride = selectHomeBanners(rows, { audience: 'CUSTOMER', service: 'RIDE', regionCode: null, now: NOW });
    expect(ride.map((b) => b.id)).toEqual(['a']);
  });

  it('reports states and ICT stat day', () => {
    expect(homeBannerState(rows[6]!, NOW)).toBe('SCHEDULED');
    expect(homeBannerState(rows[7]!, NOW)).toBe('EXPIRED');
    expect(homeBannerState(rows[5]!, NOW)).toBe('NO_IMAGE');
    expect(homeBannerStatDay(new Date('2026-10-27T18:30:00Z'))).toBe('2026-10-28');
  });

  it('maps image urls back to storage keys only for well-formed paths', () => {
    const id = '11111111-2222-4333-8444-555555555555';
    const file = '66666666-7777-4888-8999-000000000000.webp';
    expect(keyFromHomeBannerImageUrl(`/v1/public/home-banners/images/${id}/${file}`)).toBe(
      `home-banners/${id}/${file}`,
    );
    expect(keyFromHomeBannerImageUrl(`/v1/public/home-banners/images/${id}/../x.png`)).toBeNull();
    expect(keyFromHomeBannerImageUrl('/v1/public/avatars/x.png')).toBeNull();
  });
});

describe('HomeBannerService', () => {
  it('creates inactive, requires an image to activate, then serves it publicly', async () => {
    const { repo, service } = makeService();
    const created = await service.create(
      { audiences: ['CUSTOMER'], service: 'FOOD', ctaUrl: 'dealgo://customer/shop' },
      'ops-1',
    );
    expect(created.state).toBe('INACTIVE');
    expect(created.ctaUrl).toBe('/customer/shop');
    await expect(service.update(created.id, { active: true }, 'ops-1')).rejects.toThrow(/image/);
    await expect(
      service.create({ audiences: ['CUSTOMER'], active: true }, 'ops-1'),
    ).rejects.toThrow(/image/);

    const withImage = await service.uploadImage(created.id, { dataUrl: `data:image/png;base64,${PNG}` }, 'ops-1');
    expect(withImage.imageUrl).toMatch(/^\/v1\/public\/home-banners\/images\/.+\.png$/);
    await service.update(created.id, { active: true }, 'ops-1');

    const items = await service.listPublic({ role: 'CUSTOMER' });
    expect(items).toEqual([
      { id: created.id, imageUrl: withImage.imageUrl, cta: { kind: 'app', target: '/customer/shop' }, service: 'FOOD' },
    ]);
    expect(await service.listPublic({ role: 'DRIVER' })).toEqual([]);
    expect(repo.audits.map((a) => a.action)).toEqual([
      'HOME_BANNER_CREATE',
      'HOME_BANNER_UPDATE',
      'HOME_BANNER_UPDATE',
    ]);

    const file = withImage.imageUrl!.split('/').pop()!;
    const img = await service.readImage(created.id, file);
    expect(img.contentType).toBe('image/png');
  });

  it('rejects unknown regions, bad windows and empty patches', async () => {
    const { service } = makeService();
    await expect(
      service.create({ audiences: ['CUSTOMER'], regionCode: 'ZZ' }, 'ops-1'),
    ).rejects.toThrow(/region/);
    await expect(
      service.create(
        { audiences: ['CUSTOMER'], startsAt: '2026-11-02T00:00:00Z', endsAt: '2026-11-01T00:00:00Z' },
        'ops-1',
      ),
    ).rejects.toThrow(/endsAt/);
    const ok = await service.create({ audiences: ['CUSTOMER'], regionCode: 'dn' }, 'ops-1');
    expect(ok.regionCode).toBe('DN');
    await expect(service.update(ok.id, { regionCode: 'DN' }, 'ops-1')).rejects.toThrow(/No banner field/);
    await expect(service.update(ok.id, { audiences: ['DRIVER'], ctaUrl: '/customer/shop' }, 'ops-1')).rejects.toThrow(
      /CTA/,
    );
  });

  it('resolves the region from lat/lng', async () => {
    const { service } = makeService();
    const b = await service.create({ audiences: ['CUSTOMER'], regionCode: 'DN' }, 'ops-1');
    await service.uploadImage(b.id, { contentBase64: PNG, contentType: 'image/png' }, 'ops-1');
    await service.update(b.id, { active: true }, 'ops-1');
    expect(await service.listPublic({ role: 'CUSTOMER', lat: 16.06, lng: 108.22 })).toHaveLength(1);
    expect(await service.listPublic({ role: 'CUSTOMER', lat: 10.77, lng: 106.7 })).toHaveLength(0);
    expect(await service.listPublic({ role: 'CUSTOMER' })).toHaveLength(0);
  });

  it('reorders, counts live events and deletes with the image', async () => {
    const { repo, service, stored } = makeService();
    const a = await service.create({ audiences: ['CUSTOMER'] }, 'ops-1');
    const b = await service.create({ audiences: ['CUSTOMER'] }, 'ops-1');
    for (const id of [a.id, b.id]) {
      await service.uploadImage(id, { contentBase64: PNG, contentType: 'image/png' }, 'ops-1');
      await service.update(id, { active: true }, 'ops-1');
    }
    const ordered = await service.reorder([b.id, a.id], 'ops-2');
    expect(ordered.map((x) => x.id)).toEqual([b.id, a.id]);
    expect((await service.listPublic({ role: 'CUSTOMER' })).map((x) => x.id)).toEqual([b.id, a.id]);
    await expect(service.reorder(['00000000-0000-4000-8000-00000000ffff'], 'ops-2')).rejects.toThrow(/Unknown/);

    const res = await service.recordEvents([
      { bannerId: a.id, type: 'IMPRESSION' },
      { bannerId: a.id, type: 'IMPRESSION' },
      { bannerId: a.id, type: 'CLICK' },
      { bannerId: '00000000-0000-4000-8000-00000000ffff', type: 'CLICK' },
    ]);
    expect(res.accepted).toBe(3);
    const stats = (await service.listOps()).find((x) => x.id === a.id)!.stats;
    expect(stats).toMatchObject({ impressions: 2, clicks: 1, ctr: 0.5, last7d: { impressions: 2, clicks: 1 } });

    expect(stored.size).toBe(2);
    await service.remove(a.id, 'ops-3');
    expect(stored.size).toBe(1);
    expect(repo.audits.at(-1)).toMatchObject({ action: 'HOME_BANNER_DELETE', actorUserId: 'ops-3' });
    expect((await service.listPublic({ role: 'CUSTOMER' })).map((x) => x.id)).toEqual([b.id]);
  });
});
