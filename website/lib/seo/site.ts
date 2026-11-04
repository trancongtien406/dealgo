import type { Metadata } from "next";
import type { PublicSiteConfig } from "@/features/site-config/types";

/**
 * Public site identity for SEO. NEXT_PUBLIC_SITE_URL is the canonical origin
 * (production: https://dealgo.laptrinhapp.com);
 * local builds fall back to localhost so metadataBase is always absolute.
 */
export const SITE_NAME = "DealGo";

/** Brand slogan. Keep in sync with the landing hero and footer. */
export const SITE_SLOGAN = "Giá do bạn chọn, Trọn gói hành trình";

/**
 * Shared meta description. Nationwide positioning: the product is not tied to a
 * single launch city, so do not add a city name here.
 */
export const SITE_DESCRIPTION =
  "DealGo – đặt xe máy, ô tô và đặt đồ ăn trên toàn quốc. Bạn tự chọn giá, thương lượng trực tiếp với tài xế và đặt món từ quán ăn, cửa hàng gần bạn trong một ứng dụng.";

/**
 * Social preview banner (1200×630) shared by every public page.
 * Source artwork: design/brand/v3/png/DealGo Banner with White SUV.png
 */
export const OG_IMAGE = {
  url: "/og/dealgo-banner.jpg",
  width: 1200,
  height: 630,
  alt: `DealGo – ${SITE_SLOGAN}`,
} as const;

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
  "/account-deletion",
] as const;

/** Public routes that also exist in English via `?lang=en`. */
export const BILINGUAL_ROUTES = [
  "/support",
  "/terms",
  "/privacy",
  "/regulations",
  "/account-deletion",
] as const;

type PageMetaInput = {
  /** Page title without the brand suffix; the root template appends "| DealGo". */
  title: string;
  description: string;
  /** Site-relative canonical path, e.g. "/privacy". */
  path: string;
  /** Set when the page has a `?lang=en` variant so hreflang stays accurate. */
  locale?: "vi" | "en";
  /** Legal/help pages stay indexable; pass `{ index: false }` to opt out. */
  index?: boolean;
  image?: typeof OG_IMAGE;
};

/**
 * One metadata builder for every public page so canonical, Open Graph and
 * Twitter output never drift apart between routes.
 */
export function buildPageMetadata({
  title,
  description,
  path,
  locale = "vi",
  index = true,
  image = OG_IMAGE,
}: PageMetaInput): Metadata {
  const canonical = locale === "en" ? `${path}?lang=en` : path;
  const languages = { vi: path, en: `${path}?lang=en`, "x-default": path };
  return {
    title,
    description,
    alternates: {
      canonical,
      ...(BILINGUAL_ROUTES.includes(path as (typeof BILINGUAL_ROUTES)[number])
        ? { languages }
        : {}),
    },
    robots: index
      ? { index: true, follow: true }
      : { index: false, follow: false },
    openGraph: {
      type: "website",
      url: canonical,
      siteName: SITE_NAME,
      locale: locale === "en" ? "en_US" : "vi_VN",
      title,
      description,
      images: [image],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [image],
    },
  };
}

/** Schema.org graph for the landing page. No ratings or prices; store links and sameAs only when the admin set them. */
export function landingJsonLd(config: PublicSiteConfig = {}): Record<string, unknown> {
  const sameAs = Object.values(config.socials ?? {}).filter((v): v is string => Boolean(v));
  const installUrl = [config.appStoreUrl, config.googlePlayUrl].filter((v): v is string => Boolean(v));
  const origin = siteUrl().origin;
  const org = `${origin}/#organization`;
  const service = (name: string, description: string, category: string) => ({
    "@type": "Service",
    name,
    description,
    serviceType: category,
    provider: { "@id": org },
    areaServed: { "@type": "Country", name: "Việt Nam" },
    availableChannel: {
      "@type": "ServiceChannel",
      serviceUrl: `${origin}/`,
      servicePhone: config.hotline || undefined,
    },
    inLanguage: "vi-VN",
  });
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": org,
        name: SITE_NAME,
        alternateName: "DealGo Việt Nam",
        url: `${origin}/`,
        logo: {
          "@type": "ImageObject",
          url: `${origin}/dealgo-logo.svg`,
          width: 512,
          height: 512,
        },
        slogan: SITE_SLOGAN,
        description: SITE_DESCRIPTION,
        areaServed: { "@type": "Country", name: "Việt Nam" },
        ...(sameAs.length > 0 ? { sameAs } : {}),
        ...(config.contactEmail || config.hotline
          ? {
              contactPoint: {
                "@type": "ContactPoint",
                contactType: "customer support",
                areaServed: "VN",
                availableLanguage: ["vi", "en"],
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
        description: SITE_DESCRIPTION,
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
      service(
        "Đặt xe máy và ô tô thương lượng giá",
        "Khách hàng đề xuất giá, tài xế chấp nhận hoặc trả giá lại; theo dõi hành trình và thanh toán minh bạch trong ứng dụng.",
        "Ride hailing",
      ),
      service(
        "Đặt đồ ăn giao tận nơi",
        "Đặt món từ quán ăn, cửa hàng gần bạn, theo dõi tài xế giao hàng theo thời gian thực và nhận ưu đãi trong ứng dụng.",
        "Food delivery",
      ),
    ],
  };
}

/** FAQPage markup for the landing accordion. Mirrors the visible Q&A copy. */
export function faqJsonLd(faqs: readonly { q: string; a: string }[]): Record<string, unknown> {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((faq) => ({
      "@type": "Question",
      name: faq.q,
      acceptedAnswer: { "@type": "Answer", text: faq.a },
    })),
  };
}
