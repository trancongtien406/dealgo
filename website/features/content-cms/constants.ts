import type { PublicPageSlug } from "./types";

export const CONTENT_CMS_TABS = [
  "Điều khoản dịch vụ",
  "Chính sách riêng tư",
  "Quy chế sử dụng",
  "Kênh & Hỗ trợ",
] as const;

export const CONTENT_CMS_DEFAULT_TAB = CONTENT_CMS_TABS[0];

export const CONTENT_CMS_TAB_SLUG: Record<(typeof CONTENT_CMS_TABS)[number], PublicPageSlug> = {
  "Điều khoản dịch vụ": "terms",
  "Chính sách riêng tư": "privacy",
  "Quy chế sử dụng": "regulations",
  "Kênh & Hỗ trợ": "support",
};

export const PUBLIC_PAGE_HREF: Record<PublicPageSlug, string> = {
  terms: "/terms",
  privacy: "/privacy",
  regulations: "/regulations",
  support: "/support",
};
