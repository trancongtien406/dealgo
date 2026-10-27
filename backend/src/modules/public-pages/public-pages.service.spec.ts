import { describe, expect, it } from 'vitest';
import { PUBLIC_PAGE_DEFAULTS } from './public-page-defaults.js';
import { MemoryPublicPagesRepository } from './public-pages.repository.js';
import { PublicPagesService } from './public-pages.service.js';
import { PUBLIC_PAGE_LOCALES, PUBLIC_PAGE_SLUGS, contentSchemaFor } from './public-pages.types.js';

const ACTOR = '00000000-0000-4000-8000-000000000001';

function setup() {
  const repo = new MemoryPublicPagesRepository();
  return { repo, svc: new PublicPagesService(repo) };
}

describe('PublicPagesService', () => {
  it('ships valid vi/en defaults for every page without fake contact data', () => {
    for (const slug of PUBLIC_PAGE_SLUGS) {
      for (const locale of PUBLIC_PAGE_LOCALES) {
        const d = PUBLIC_PAGE_DEFAULTS[slug][locale];
        expect(contentSchemaFor(slug).safeParse(d.content).success).toBe(true);
        expect(JSON.stringify(d)).not.toMatch(/1900 ?6868|hotro@dealgo\.vn/);
      }
    }
  });

  it('serves the built-in default (version 0) before anything is published', async () => {
    const { svc } = setup();
    const view = await svc.getPublic('privacy', 'vi');
    expect(view).toMatchObject({ source: 'default', version: 0, title: 'Chính sách quyền riêng tư' });
  });

  it('keeps drafts private until published, then versions and audits each publish', async () => {
    const { svc, repo } = setup();
    const content = { badge: 'v', sections: [{ id: 'a', title: 'A', content: 'Nội dung' }] };
    const draft = await svc.saveDraft('terms', 'vi', { title: 'Điều khoản', content, effectiveAt: '2026-11-01' }, ACTOR);
    expect(draft).toMatchObject({ status: 'DRAFT', version: 0, hasDraft: true });
    expect((await svc.getPublic('terms', 'vi')).source).toBe('default');

    const v1 = await svc.publish('terms', 'vi', 'Ra mắt', ACTOR);
    expect(v1).toMatchObject({ status: 'PUBLISHED', version: 1, hasDraft: false });
    const pub = await svc.getPublic('terms', 'vi');
    expect(pub).toMatchObject({ source: 'cms', version: 1, title: 'Điều khoản', effectiveAt: '2026-11-01T00:00:00.000Z' });
    expect(repo.audits).toHaveLength(1);
    expect(repo.audits[0]).toMatchObject({ actorUserId: ACTOR, reason: 'Ra mắt', metadata: { slug: 'terms', locale: 'vi', version: 1 } });

    await expect(svc.publish('terms', 'vi', 'again', ACTOR)).rejects.toMatchObject({ status: 409 });

    await svc.saveDraft('terms', 'vi', { title: 'Điều khoản 2', content }, ACTOR);
    expect((await svc.getPublic('terms', 'vi')).title).toBe('Điều khoản');
    await svc.publish('terms', 'vi', 'Cập nhật', ACTOR);
    expect((await svc.getPublic('terms', 'vi')).version).toBe(2);
    expect((await svc.revisions('terms', 'vi')).map((r) => r.version)).toEqual([2, 1]);
  });

  it('falls back from en to published vi', async () => {
    const { svc } = setup();
    await svc.publish('support', 'vi', 'Ra mắt', ACTOR);
    const en = await svc.getPublic('support', 'en');
    expect(en).toMatchObject({ locale: 'vi', source: 'cms', version: 1 });
  });

  it('rejects invalid content, unknown slugs and locales', async () => {
    const { svc } = setup();
    await expect(svc.saveDraft('privacy', 'vi', { title: 'x', content: { sections: [] } }, ACTOR)).rejects.toMatchObject({
      status: 400,
    });
    expect(() => svc.parseSlug('about')).toThrow();
    expect(() => svc.parseLocale('fr')).toThrow();
    expect(svc.parseLocale(undefined)).toBe('vi');
  });

  it('reset restores the default as a draft', async () => {
    const { svc } = setup();
    await svc.saveDraft('privacy', 'en', { title: 'Custom', content: { sections: [{ id: 'a', title: 'A', content: 'B' }] } }, ACTOR);
    const reset = await svc.reset('privacy', 'en', ACTOR);
    expect(reset).toMatchObject({ title: 'Privacy Policy', status: 'DRAFT' });
  });
});
