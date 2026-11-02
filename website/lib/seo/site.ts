import type { PublicSiteConfig } from "@/features/site-config/types";

/**
 * Public site identity for SEO. NEXT_PUBLIC_SITE_URL is the canonical origin
 * (e.g. https://dealgo.vn — OPEN DECISION: production domain not confirmed);
 * local builds fall back to localhost so metadataBase is always absolute.
 */
export const SITE_NAME = "DealGo";

export const SITE_DESCRIPTION =
  "DealGo là ứng dụng đặt xe máy, ô tô và đặt đồ ăn tại Đà Nẵng. Khách hàng đề xuất giá và thương lượng trực tiếp với tài xế; quán ăn, cửa hàng và tài xế dùng chung một ứng dụng.";

export function siteUrl(): URL {
  const raw = process.env.NEXT_PUBLIC_SITE_URL?.trim();
  if (raw) {
    try {
      return new URL(raw);
    } catch {
      // Fall through to the local default rather than failing every page.
    }
  }
  return new URL("http://localhost:3000");
}

/** Public, indexable routes. Admin, auth, API and share-token pages stay out. */
export const PUBLIC_ROUTES = [
  "/",
  "/support",
  "/terms",
  "/privacy",
  "/regulations",
] as const;

/** Schema.org graph for the landing page. No ratings or prices; store links and sameAs only when the admin set them. */
export function landingJsonLd(config: PublicSiteConfig = {}): Record<string, unknown> {
  const sameAs = Object.values(config.socials ?? {}).filter((v): v is string => Boolean(v));
  const installUrl = [config.appStoreUrl, config.googlePlayUrl].filter((v): v is string => Boolean(v));
  const origin = siteUrl().origin;
  const org = `${origin}/#organization`;
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": org,
        name: SITE_NAME,
        url: `${origin}/`,
        logo: `${origin}/dealgo-logo.svg`,
        areaServed: { "@type": "City", name: "Đà Nẵng" },
        ...(sameAs.length > 0 ? { sameAs } : {}),
        ...(config.contactEmail || config.hotline
          ? {
              contactPoint: {
                "@type": "ContactPoint",
                contactType: "customer support",
                ...(config.contactEmail ? { email: config.contactEmail } : {}),
                ...(config.hotline ? { telephone: config.hotline } : {}),
              },
            }
          : {}),
      },
      {
        "@type": "WebSite",
        "@id": `${origin}/#website`,
        name: SITE_NAME,
        url: `${origin}/`,
        inLanguage: "vi-VN",
        publisher: { "@id": org },
      },
      {
        "@type": "MobileApplication",
        name: SITE_NAME,
        operatingSystem: "iOS, Android",
        applicationCategory: "TravelApplication",
        description: SITE_DESCRIPTION,
        inLanguage: "vi-VN",
        publisher: { "@id": org },
        ...(installUrl.length > 0 ? { installUrl, downloadUrl: installUrl } : {}),
      },
    ],
  };
}
