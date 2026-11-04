import { afterEach, describe, expect, it, vi } from "vitest";
import {
  buildPageMetadata,
  faqJsonLd,
  landingJsonLd,
  PUBLIC_ROUTES,
  SITE_DESCRIPTION,
  SITE_SLOGAN,
  siteUrl,
} from "./site";

afterEach(() => vi.unstubAllEnvs());

describe("seo site", () => {
  it("uses NEXT_PUBLIC_SITE_URL and falls back to localhost", () => {
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "https://example.test/");
    expect(siteUrl().origin).toBe("https://example.test");
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "not a url");
    expect(siteUrl().origin).toBe("http://localhost:3000");
  });

  it("never lists private routes or invents ratings", () => {
    expect(
      PUBLIC_ROUTES.some((r) => /login|overview|api|chia-se/.test(r)),
    ).toBe(false);
    const json = JSON.stringify(landingJsonLd());
    expect(json).not.toMatch(/aggregateRating|ratingValue|offers/);
  });

  it("positions the product nationwide, not in a single city", () => {
    expect(SITE_DESCRIPTION).not.toMatch(/Đà Nẵng|Da Nang|Hà Nội|Hồ Chí Minh/);
    expect(SITE_DESCRIPTION).toContain("toàn quốc");
    expect(SITE_SLOGAN).toBe("Giá do bạn chọn, Trọn gói hành trình");
    expect(JSON.stringify(landingJsonLd())).toContain(SITE_SLOGAN);
  });

  it("builds canonical, hreflang and social tags for a public page", () => {
    vi.stubEnv("NEXT_PUBLIC_SITE_URL", "https://example.test");
    const viMeta = buildPageMetadata({
      title: "Chính sách quyền riêng tư",
      description: "Mô tả",
      path: "/privacy",
    });
    expect(viMeta.alternates?.canonical).toBe("/privacy");
    expect(viMeta.alternates?.languages).toMatchObject({
      vi: "/privacy",
      en: "/privacy?lang=en",
    });
    expect(viMeta.robots).toMatchObject({ index: true, follow: true });
    expect(viMeta.openGraph?.images).toHaveLength(1);
    expect((viMeta.twitter as { card?: string }).card).toBe("summary_large_image");

    const enMeta = buildPageMetadata({
      title: "Privacy policy",
      description: "Description",
      path: "/privacy",
      locale: "en",
    });
    expect(enMeta.alternates?.canonical).toBe("/privacy?lang=en");
    expect(enMeta.openGraph?.locale).toBe("en_US");

    const privateMeta = buildPageMetadata({
      title: "Nội bộ",
      description: "Mô tả",
      path: "/overseas",
      index: false,
    });
    expect(privateMeta.robots).toMatchObject({ index: false, follow: false });
  });

  it("turns the landing FAQ into FAQPage markup", () => {
    const json = faqJsonLd([
      { q: "DealGo là gì?", a: "Ứng dụng đặt xe và đồ ăn." },
    ]) as { "@type": string; mainEntity: { name: string }[] };
    expect(json["@type"]).toBe("FAQPage");
    expect(json.mainEntity[0].name).toBe("DealGo là gì?");
  });
});
