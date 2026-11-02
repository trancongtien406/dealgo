import { describe, expect, it } from 'vitest';
import { MemoryPublicPagesRepository } from '../public-pages/public-pages.repository.js';
import { PublicPagesService } from '../public-pages/public-pages.service.js';
import { PUBLIC_PAGE_DEFAULTS } from '../public-pages/public-page-defaults.js';
import { LegalConsentService } from './legal-consent.service.js';

const ACTOR = '00000000-0000-4000-8000-000000000001';

function setup() {
  const pages = new PublicPagesService(new MemoryPublicPagesRepository());
  return { pages, legal: new LegalConsentService(pages) };
}

describe('pt5u: Quy chế sử dụng + privacy consent for driver/shop applications', () => {
  it('ships a built-in regulations page editable like privacy/terms', async () => {
    const { pages } = setup();
    const view = await pages.getPublic('regulations', 'vi');
    expect(view.source).toBe('default');
    expect(view.title).toBe('Quy chế sử dụng dành cho tài xế và cửa hàng');
    for (const loc of ['vi', 'en'] as const) {
      const text = JSON.stringify(PUBLIC_PAGE_DEFAULTS.regulations[loc].content);
      expect(text).toContain('"sections"');
      // Commission rates are still an open decision: no percentages are published.
      expect(text).not.toMatch(/\d+\s?%/);
    }
  });

  it('requires the current version of both documents', async () => {
    const { legal } = setup();
    await expect(legal.assertApplicationConsent(undefined)).rejects.toMatchObject({ status: 400 });
    await expect(legal.assertApplicationConsent([{ slug: 'privacy', version: 0 }])).rejects.toMatchObject({
      response: { errorCode: 'PARTNER_LEGAL_CONSENT_REQUIRED' },
    });
    await expect(
      legal.assertApplicationConsent([
        { slug: 'regulations', version: 0 },
        { slug: 'privacy', version: 0 },
      ]),
    ).resolves.toEqual([
      { slug: 'regulations', version: 0 },
      { slug: 'privacy', version: 0 },
    ]);
  });

  it('a newly published regulations version invalidates the old acceptance', async () => {
    const { pages, legal } = setup();
    const content = PUBLIC_PAGE_DEFAULTS.regulations.vi.content;
    await pages.saveDraft('regulations', 'vi', { title: 'Quy chế sử dụng', content }, ACTOR);
    await pages.publish('regulations', 'vi', 'Bản 1', ACTOR);
    expect(await legal.currentApplicationDocuments()).toEqual([
      { slug: 'regulations', version: 1 },
      { slug: 'privacy', version: 0 },
    ]);
    await expect(
      legal.assertApplicationConsent([
        { slug: 'regulations', version: 0 },
        { slug: 'privacy', version: 0 },
      ]),
    ).rejects.toMatchObject({ status: 400 });
    // Without a database the audit rows are skipped, never thrown.
    await expect(legal.recordApplicationConsent('u1', 'DRIVER', [{ slug: 'regulations', version: 1 }])).resolves.toBeUndefined();
  });
});
