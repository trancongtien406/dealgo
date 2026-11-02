import type {
  LegalContent,
  PublicPageLocale,
  LegalPageSlug,
  PublicPageSlug,
  PublicPageView,
  SupportContent,
} from "./types";

/**
 * Offline fallback used only when the API is unreachable. The real default content lives in the
 * backend (public-page-defaults.ts) and is edited in Cài đặt → Nội dung.
 */
const UNAVAILABLE: Record<PublicPageLocale, string> = {
  vi: "Nội dung tạm thời chưa tải được. Vui lòng thử lại sau.",
  en: "This content is temporarily unavailable. Please try again later.",
};

const TITLES: Record<PublicPageSlug, Record<PublicPageLocale, string>> = {
  terms: { vi: "Điều khoản sử dụng", en: "Terms of Use" },
  privacy: { vi: "Chính sách quyền riêng tư", en: "Privacy Policy" },
  regulations: { vi: "Quy chế sử dụng", en: "Regulations" },
  support: { vi: "Trung tâm hỗ trợ", en: "Support" },
};

export function fallbackLegalPage(
  slug: LegalPageSlug,
  locale: PublicPageLocale,
): PublicPageView<LegalContent> {
  return {
    slug,
    locale,
    title: TITLES[slug][locale],
    summary: null,
    content: {
      badge: "",
      sections: [{ id: "unavailable", title: TITLES[slug][locale], content: UNAVAILABLE[locale] }],
    },
    version: 0,
    effectiveAt: null,
    publishedAt: null,
    source: "default",
  };
}

export function fallbackSupportPage(locale: PublicPageLocale): PublicPageView<SupportContent> {
  return {
    slug: "support",
    locale,
    title: TITLES.support[locale],
    summary: null,
    content: {
      systemStatusNotice: "",
      hotline: "",
      email: "",
      address: "",
      hours: "",
      categories: [],
    },
    version: 0,
    effectiveAt: null,
    publishedAt: null,
    source: "default",
  };
}

/** Real contact value for display; hides empty or unfilled "[...]" placeholders. */
export function shownContact(value: string): string | null {
  const v = value.trim();
  return v && !/^\[.*\]$/.test(v) ? v : null;
}
