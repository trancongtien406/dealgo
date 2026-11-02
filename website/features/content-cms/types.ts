/** DEC-PROD-055: public pages served by Nest `/v1/public/pages/:slug`. */
export const PUBLIC_PAGE_SLUGS = ["terms", "privacy", "regulations", "support"] as const;
/** Legal documents rendered by LegalPageView (everything except support). */
export type LegalPageSlug = Exclude<PublicPageSlug, "support">;
export type PublicPageSlug = (typeof PUBLIC_PAGE_SLUGS)[number];
export const PUBLIC_PAGE_LOCALES = ["vi", "en"] as const;
export type PublicPageLocale = (typeof PUBLIC_PAGE_LOCALES)[number];

export type LegalSection = {
  id: string;
  title: string;
  content: string;
};

export type LegalContent = {
  badge: string;
  sections: LegalSection[];
};

export type SupportRole = "CUSTOMER" | "DRIVER" | "MERCHANT";

export type SupportCategory = {
  id: string;
  title: string;
  role: SupportRole;
  icon: string;
  tone: string;
  items: string[];
};

export type SupportContent = {
  systemStatusNotice: string;
  hotline: string;
  email: string;
  address: string;
  hours: string;
  categories: SupportCategory[];
};

export type PublicPageContentFor<S extends PublicPageSlug> = S extends "support"
  ? SupportContent
  : LegalContent;

export type PublicPageView<C = LegalContent | SupportContent> = {
  slug: PublicPageSlug;
  locale: PublicPageLocale;
  title: string;
  summary: string | null;
  content: C;
  version: number;
  effectiveAt: string | null;
  publishedAt: string | null;
  source: "cms" | "default";
};

export type OpsPublicPageView<C = LegalContent | SupportContent> =
  PublicPageView<C> & {
    status: "DRAFT" | "PUBLISHED";
    hasDraft: boolean;
    updatedAt: string | null;
    updatedByUserId: string | null;
  };

export type PublicPageRevision<C = LegalContent | SupportContent> = {
  version: number;
  title: string;
  summary: string | null;
  content: C;
  effectiveAt: string | null;
  publishedAt: string | null;
  publishedByUserId: string | null;
};

export type PublicPageDraft<C = LegalContent | SupportContent> = {
  title: string;
  summary: string | null;
  effectiveAt: string | null;
  content: C;
};

export function isPublicPageSlug(v: string): v is PublicPageSlug {
  return (PUBLIC_PAGE_SLUGS as readonly string[]).includes(v);
}

export function isPublicPageLocale(v: string): v is PublicPageLocale {
  return (PUBLIC_PAGE_LOCALES as readonly string[]).includes(v);
}

export function localeFromLang(lang: string | string[] | undefined): PublicPageLocale {
  const v = Array.isArray(lang) ? lang[0] : lang;
  return v === "en" ? "en" : "vi";
}
