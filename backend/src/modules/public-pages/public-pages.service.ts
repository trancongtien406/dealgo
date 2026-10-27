import { Inject, Injectable } from '@nestjs/common';
import { PUBLIC_PAGE_DEFAULTS } from './public-page-defaults.js';
import { publicPageError } from './public-pages.error.js';
import type { PublicPagesRepository } from './public-pages.repository.js';
import {
  PUBLIC_PAGE_BODY_MAX,
  PUBLIC_PAGE_DEFAULT_LOCALE,
  PUBLIC_PAGE_LOCALES,
  PUBLIC_PAGE_SLUGS,
  PUBLIC_PAGES_REPOSITORY,
  contentSchemaFor,
  type PublicPageContent,
  type PublicPageLocale,
  type PublicPageRecord,
  type PublicPageRevisionRecord,
  type PublicPageSlug,
  type PublicPageView,
} from './public-pages.types.js';

export type OpsPublicPageView = PublicPageView & {
  status: 'DRAFT' | 'PUBLISHED';
  /** True when the stored draft differs from the last published revision. */
  hasDraft: boolean;
  updatedAt: string | null;
  updatedByUserId: string | null;
};

export type SaveDraftInput = {
  title: string;
  summary?: string | null;
  effectiveAt?: string | null;
  content: unknown;
};

const iso = (d: Date | null | undefined) => (d ? d.toISOString() : null);

@Injectable()
export class PublicPagesService {
  constructor(@Inject(PUBLIC_PAGES_REPOSITORY) private readonly repo: PublicPagesRepository) {}

  parseSlug(raw: string): PublicPageSlug {
    if (!(PUBLIC_PAGE_SLUGS as readonly string[]).includes(raw)) throw publicPageError('PUBLIC_PAGE_NOT_FOUND');
    return raw as PublicPageSlug;
  }

  parseLocale(raw: string | undefined): PublicPageLocale {
    if (raw === undefined || raw === '') return PUBLIC_PAGE_DEFAULT_LOCALE;
    if (!(PUBLIC_PAGE_LOCALES as readonly string[]).includes(raw)) throw publicPageError('PUBLIC_PAGE_NOT_FOUND');
    return raw as PublicPageLocale;
  }

  /** Published content: requested locale → Vietnamese → built-in default. */
  async getPublic(slug: PublicPageSlug, locale: PublicPageLocale): Promise<PublicPageView> {
    const rev = await this.repo.latestRevision(slug, locale);
    if (rev) return this.fromRevision(slug, locale, rev);
    if (locale !== PUBLIC_PAGE_DEFAULT_LOCALE) {
      const fallback = await this.repo.latestRevision(slug, PUBLIC_PAGE_DEFAULT_LOCALE);
      if (fallback) return this.fromRevision(slug, PUBLIC_PAGE_DEFAULT_LOCALE, fallback);
    }
    return this.defaultView(slug, locale);
  }

  async listOps(): Promise<OpsPublicPageView[]> {
    const out: OpsPublicPageView[] = [];
    for (const slug of PUBLIC_PAGE_SLUGS) {
      for (const locale of PUBLIC_PAGE_LOCALES) out.push(await this.getOps(slug, locale));
    }
    return out;
  }

  async getOps(slug: PublicPageSlug, locale: PublicPageLocale): Promise<OpsPublicPageView> {
    const page = await this.repo.find(slug, locale);
    if (!page) {
      return { ...this.defaultView(slug, locale), status: 'DRAFT', hasDraft: false, updatedAt: null, updatedByUserId: null };
    }
    return this.fromRecord(page, await this.repo.latestRevision(slug, locale));
  }

  async saveDraft(
    slug: PublicPageSlug,
    locale: PublicPageLocale,
    input: SaveDraftInput,
    actorUserId: string | null,
  ): Promise<OpsPublicPageView> {
    const parsed = contentSchemaFor(slug).safeParse(input.content);
    if (!parsed.success) {
      throw publicPageError(
        'PUBLIC_PAGE_INVALID',
        parsed.error.issues.slice(0, 10).map((i) => ({ path: i.path.join('.'), message: i.message })),
      );
    }
    const body = JSON.stringify(parsed.data);
    if (body.length > PUBLIC_PAGE_BODY_MAX) throw publicPageError('PUBLIC_PAGE_INVALID');
    const title = input.title.trim();
    if (!title) throw publicPageError('PUBLIC_PAGE_INVALID');
    const page = await this.repo.saveDraft(
      {
        slug,
        locale,
        title,
        summary: input.summary?.trim() || null,
        body,
        effectiveAt: input.effectiveAt ? new Date(input.effectiveAt) : null,
      },
      actorUserId,
    );
    return this.fromRecord(page, await this.repo.latestRevision(slug, locale));
  }

  /** Publishes the stored draft, or the built-in default when nothing was ever saved. */
  async publish(
    slug: PublicPageSlug,
    locale: PublicPageLocale,
    reason: string,
    actorUserId: string,
  ): Promise<OpsPublicPageView> {
    let page = await this.repo.find(slug, locale);
    if (!page) {
      await this.reset(slug, locale, actorUserId);
      page = await this.repo.find(slug, locale);
    } else if (page.status === 'PUBLISHED') {
      throw publicPageError('PUBLIC_PAGE_NOTHING_TO_PUBLISH');
    }
    const published = await this.repo.publish(slug, locale, actorUserId, reason.trim());
    if (!published) throw publicPageError('PUBLIC_PAGE_NOT_FOUND');
    return this.fromRecord(published, await this.repo.latestRevision(slug, locale));
  }

  /** Replaces the draft with the built-in default (published content stays until the next publish). */
  async reset(slug: PublicPageSlug, locale: PublicPageLocale, actorUserId: string | null) {
    const d = PUBLIC_PAGE_DEFAULTS[slug][locale];
    return this.saveDraft(slug, locale, { title: d.title, summary: d.summary, content: d.content }, actorUserId);
  }

  async revisions(slug: PublicPageSlug, locale: PublicPageLocale) {
    const rows = await this.repo.revisions(slug, locale, 50);
    return rows.map((r) => ({
      version: r.version,
      title: r.title,
      summary: r.summary,
      content: this.parseBody(slug, r.body),
      effectiveAt: iso(r.effectiveAt),
      publishedAt: iso(r.publishedAt),
      publishedByUserId: r.publishedByUserId,
    }));
  }

  private parseBody(slug: PublicPageSlug, body: string): PublicPageContent {
    try {
      const parsed = contentSchemaFor(slug).safeParse(JSON.parse(body));
      if (parsed.success) return parsed.data;
    } catch {
      /* fall through to default */
    }
    return PUBLIC_PAGE_DEFAULTS[slug][PUBLIC_PAGE_DEFAULT_LOCALE].content;
  }

  private defaultView(slug: PublicPageSlug, locale: PublicPageLocale): PublicPageView {
    const d = PUBLIC_PAGE_DEFAULTS[slug][locale];
    return {
      slug,
      locale,
      title: d.title,
      summary: d.summary,
      content: d.content,
      version: 0,
      effectiveAt: null,
      publishedAt: null,
      source: 'default',
    };
  }

  private fromRevision(slug: PublicPageSlug, locale: PublicPageLocale, rev: PublicPageRevisionRecord): PublicPageView {
    return {
      slug,
      locale,
      title: rev.title,
      summary: rev.summary,
      content: this.parseBody(slug, rev.body),
      version: rev.version,
      effectiveAt: iso(rev.effectiveAt),
      publishedAt: iso(rev.publishedAt),
      source: 'cms',
    };
  }

  private fromRecord(page: PublicPageRecord, rev: PublicPageRevisionRecord | null): OpsPublicPageView {
    const hasDraft =
      !rev ||
      rev.title !== page.title ||
      rev.summary !== page.summary ||
      rev.body !== page.body ||
      iso(rev.effectiveAt) !== iso(page.effectiveAt);
    return {
      slug: page.slug,
      locale: page.locale,
      title: page.title,
      summary: page.summary,
      content: this.parseBody(page.slug, page.body),
      version: page.version,
      effectiveAt: iso(page.effectiveAt),
      publishedAt: iso(page.publishedAt),
      source: 'cms',
      status: page.status,
      hasDraft,
      updatedAt: iso(page.updatedAt),
      updatedByUserId: page.updatedByUserId,
    };
  }
}
