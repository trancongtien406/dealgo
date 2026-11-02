import { z } from 'zod';

/** DEC-PROD-055: admin-editable public pages. */
export const PUBLIC_PAGE_SLUGS = ['privacy', 'terms', 'regulations', 'support'] as const;
export type PublicPageSlug = (typeof PUBLIC_PAGE_SLUGS)[number];
export const PUBLIC_PAGE_LOCALES = ['vi', 'en'] as const;
export type PublicPageLocale = (typeof PUBLIC_PAGE_LOCALES)[number];
export const PUBLIC_PAGE_DEFAULT_LOCALE: PublicPageLocale = 'vi';
export const PUBLIC_PAGE_BODY_MAX = 100_000;

export const PUBLIC_PAGES_REPOSITORY = Symbol('PUBLIC_PAGES_REPOSITORY');

const text = (max: number) => z.string().trim().max(max);

export const legalContentSchema = z.object({
  badge: text(120).optional().default(''),
  sections: z
    .array(
      z.object({
        id: text(60).min(1),
        title: text(200).min(1),
        content: text(20_000).min(1),
      }),
    )
    .min(1)
    .max(60),
});
export type LegalContent = z.infer<typeof legalContentSchema>;

export const supportContentSchema = z.object({
  systemStatusNotice: text(300).default(''),
  hotline: text(40).default(''),
  email: text(120).default(''),
  address: text(300).default(''),
  hours: text(120).default(''),
  categories: z
    .array(
      z.object({
        id: text(60).min(1),
        title: text(120).min(1),
        role: z.enum(['CUSTOMER', 'DRIVER', 'MERCHANT']),
        icon: text(40).default('headset'),
        tone: text(20).default('neutral'),
        items: z.array(text(300).min(1)).max(30),
      }),
    )
    .max(12),
});
export type SupportContent = z.infer<typeof supportContentSchema>;

export type PublicPageContent = LegalContent | SupportContent;

export function contentSchemaFor(slug: PublicPageSlug) {
  return slug === 'support' ? supportContentSchema : legalContentSchema;
}

export type PublicPageRecord = {
  id: string;
  slug: PublicPageSlug;
  locale: PublicPageLocale;
  title: string;
  summary: string | null;
  /** JSON-serialised LegalContent or SupportContent. */
  body: string;
  status: 'DRAFT' | 'PUBLISHED';
  version: number;
  effectiveAt: Date | null;
  publishedAt: Date | null;
  updatedAt: Date;
  updatedByUserId: string | null;
};

export type PublicPageRevisionRecord = {
  version: number;
  title: string;
  summary: string | null;
  body: string;
  effectiveAt: Date | null;
  publishedAt: Date;
  publishedByUserId: string | null;
};

export type PublicPageDraftInput = {
  slug: PublicPageSlug;
  locale: PublicPageLocale;
  title: string;
  summary: string | null;
  body: string;
  effectiveAt: Date | null;
};

export type PublicPageView = {
  slug: PublicPageSlug;
  locale: PublicPageLocale;
  title: string;
  summary: string | null;
  content: PublicPageContent;
  version: number;
  effectiveAt: string | null;
  publishedAt: string | null;
  source: 'cms' | 'default';
};
