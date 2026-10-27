import { randomUUID } from 'node:crypto';
import type { PrismaClient } from '../../generated/prisma/client.js';
import type {
  PublicPageDraftInput,
  PublicPageLocale,
  PublicPageRecord,
  PublicPageRevisionRecord,
  PublicPageSlug,
} from './public-pages.types.js';

export interface PublicPagesRepository {
  find(slug: PublicPageSlug, locale: PublicPageLocale): Promise<PublicPageRecord | null>;
  list(): Promise<PublicPageRecord[]>;
  saveDraft(input: PublicPageDraftInput, actorUserId: string | null): Promise<PublicPageRecord>;
  /** Bumps the version, snapshots a revision and writes the audit row atomically. */
  publish(
    slug: PublicPageSlug,
    locale: PublicPageLocale,
    actorUserId: string,
    reason: string,
  ): Promise<PublicPageRecord | null>;
  latestRevision(slug: PublicPageSlug, locale: PublicPageLocale): Promise<PublicPageRevisionRecord | null>;
  revisions(slug: PublicPageSlug, locale: PublicPageLocale, limit: number): Promise<PublicPageRevisionRecord[]>;
}

type PageRow = {
  id: string;
  slug: string;
  locale: string;
  title: string;
  summary: string | null;
  body: string;
  status: 'DRAFT' | 'PUBLISHED';
  version: number;
  effectiveAt: Date | null;
  publishedAt: Date | null;
  updatedAt: Date;
  updatedByUserId: string | null;
};

function toRecord(row: PageRow): PublicPageRecord {
  return {
    id: row.id,
    slug: row.slug as PublicPageSlug,
    locale: row.locale as PublicPageLocale,
    title: row.title,
    summary: row.summary,
    body: row.body,
    status: row.status,
    version: row.version,
    effectiveAt: row.effectiveAt,
    publishedAt: row.publishedAt,
    updatedAt: row.updatedAt,
    updatedByUserId: row.updatedByUserId,
  };
}

const revisionSelect = {
  version: true,
  title: true,
  summary: true,
  body: true,
  effectiveAt: true,
  publishedAt: true,
  publishedByUserId: true,
} as const;

export class PrismaPublicPagesRepository implements PublicPagesRepository {
  constructor(private readonly db: PrismaClient) {}

  async find(slug: PublicPageSlug, locale: PublicPageLocale) {
    const row = await this.db.publicPage.findUnique({ where: { slug_locale: { slug, locale } } });
    return row ? toRecord(row) : null;
  }

  async list() {
    const rows = await this.db.publicPage.findMany({ orderBy: [{ slug: 'asc' }, { locale: 'asc' }] });
    return rows.map(toRecord);
  }

  async saveDraft(input: PublicPageDraftInput, actorUserId: string | null) {
    const data = {
      title: input.title,
      summary: input.summary,
      body: input.body,
      effectiveAt: input.effectiveAt,
      status: 'DRAFT' as const,
      updatedByUserId: actorUserId,
    };
    const row = await this.db.publicPage.upsert({
      where: { slug_locale: { slug: input.slug, locale: input.locale } },
      create: { slug: input.slug, locale: input.locale, ...data },
      update: data,
    });
    return toRecord(row);
  }

  async publish(slug: PublicPageSlug, locale: PublicPageLocale, actorUserId: string, reason: string) {
    return this.db.$transaction(async (tx) => {
      const page = await tx.publicPage.findUnique({ where: { slug_locale: { slug, locale } } });
      if (!page) return null;
      const version = page.version + 1;
      const publishedAt = new Date();
      const updated = await tx.publicPage.update({
        where: { id: page.id },
        data: { version, status: 'PUBLISHED', publishedAt, updatedByUserId: actorUserId },
      });
      await tx.publicPageRevision.create({
        data: {
          pageId: page.id,
          version,
          title: page.title,
          summary: page.summary,
          body: page.body,
          effectiveAt: page.effectiveAt,
          publishedAt,
          publishedByUserId: actorUserId,
        },
      });
      await tx.opsAuditLog.create({
        data: {
          actorUserId,
          action: 'PUBLIC_PAGE_PUBLISH',
          entityType: 'PUBLIC_PAGE',
          entityId: page.id,
          reason,
          metadata: { slug, locale, version },
        },
      });
      return toRecord(updated);
    });
  }

  async latestRevision(slug: PublicPageSlug, locale: PublicPageLocale) {
    return this.db.publicPageRevision.findFirst({
      where: { page: { slug, locale } },
      orderBy: { version: 'desc' },
      select: revisionSelect,
    });
  }

  async revisions(slug: PublicPageSlug, locale: PublicPageLocale, limit: number) {
    return this.db.publicPageRevision.findMany({
      where: { page: { slug, locale } },
      orderBy: { version: 'desc' },
      take: limit,
      select: revisionSelect,
    });
  }
}

/** Dev/test store; audit rows are kept in `audits` for assertions. */
export class MemoryPublicPagesRepository implements PublicPagesRepository {
  private readonly pages = new Map<string, PublicPageRecord>();
  private readonly revs = new Map<string, PublicPageRevisionRecord[]>();
  readonly audits: Array<{ actorUserId: string; entityId: string; reason: string; metadata: unknown }> = [];

  private key(slug: string, locale: string) {
    return `${slug}:${locale}`;
  }

  async find(slug: PublicPageSlug, locale: PublicPageLocale) {
    return this.pages.get(this.key(slug, locale)) ?? null;
  }

  async list() {
    return [...this.pages.values()].sort((a, b) => this.key(a.slug, a.locale).localeCompare(this.key(b.slug, b.locale)));
  }

  async saveDraft(input: PublicPageDraftInput, actorUserId: string | null) {
    const k = this.key(input.slug, input.locale);
    const prev = this.pages.get(k);
    const next: PublicPageRecord = {
      id: prev?.id ?? randomUUID(),
      slug: input.slug,
      locale: input.locale,
      title: input.title,
      summary: input.summary,
      body: input.body,
      status: 'DRAFT',
      version: prev?.version ?? 0,
      effectiveAt: input.effectiveAt,
      publishedAt: prev?.publishedAt ?? null,
      updatedAt: new Date(),
      updatedByUserId: actorUserId,
    };
    this.pages.set(k, next);
    return next;
  }

  async publish(slug: PublicPageSlug, locale: PublicPageLocale, actorUserId: string, reason: string) {
    const k = this.key(slug, locale);
    const page = this.pages.get(k);
    if (!page) return null;
    const publishedAt = new Date();
    const next: PublicPageRecord = {
      ...page,
      version: page.version + 1,
      status: 'PUBLISHED',
      publishedAt,
      updatedAt: publishedAt,
      updatedByUserId: actorUserId,
    };
    this.pages.set(k, next);
    const list = this.revs.get(k) ?? [];
    list.push({
      version: next.version,
      title: page.title,
      summary: page.summary,
      body: page.body,
      effectiveAt: page.effectiveAt,
      publishedAt,
      publishedByUserId: actorUserId,
    });
    this.revs.set(k, list);
    this.audits.push({ actorUserId, entityId: page.id, reason, metadata: { slug, locale, version: next.version } });
    return next;
  }

  async latestRevision(slug: PublicPageSlug, locale: PublicPageLocale) {
    const list = this.revs.get(this.key(slug, locale)) ?? [];
    return list.at(-1) ?? null;
  }

  async revisions(slug: PublicPageSlug, locale: PublicPageLocale, limit: number) {
    return [...(this.revs.get(this.key(slug, locale)) ?? [])].reverse().slice(0, limit);
  }
}
