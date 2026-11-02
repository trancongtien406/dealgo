import { describe, expect, it } from "vitest";
import { landingJsonLd } from "@/lib/seo/site";
import { PARTNER_POLICY } from "@/features/partner-policy/content";
import { linkError, safeSiteConfig } from "./validate";

describe("site config", () => {
  it("accepts only https on allowed hosts", () => {
    expect(linkError("appStoreUrl", "https://apps.apple.com/vn/app/x/id1")).toBeNull();
    expect(linkError("appStoreUrl", "")).toBeNull();
    expect(linkError("appStoreUrl", "http://apps.apple.com/x")).toMatch(/https/);
    expect(linkError("zalo", "https://zalo.me.evil.com/x")).toMatch(/Chỉ chấp nhận/);
    expect(linkError("messenger", "https://m.me/dealgo")).toBeNull();
    expect(linkError("messenger", "https://www.facebook.com/dealgo")).toMatch(/Chỉ chấp nhận/);
  });

  it("drops invalid or empty values so nothing fake renders", () => {
    expect(
      safeSiteConfig({
        appStoreUrl: "javascript:alert(1)",
        googlePlayUrl: "https://play.google.com/store/apps/details?id=vn.dealgo",
        socials: { facebook: "", tiktok: "https://www.tiktok.com/@dealgo", youtube: "https://evil.com" },
        hotline: "abc",
      }),
    ).toEqual({
      googlePlayUrl: "https://play.google.com/store/apps/details?id=vn.dealgo",
      socials: { tiktok: "https://www.tiktok.com/@dealgo" },
    });
    expect(safeSiteConfig(null)).toEqual({});
  });

  it("adds sameAs and store links to JSON-LD only when set", () => {
    const empty = JSON.stringify(landingJsonLd({}));
    expect(empty).not.toContain("sameAs");
    expect(empty).not.toContain("installUrl");
    const full = JSON.stringify(
      landingJsonLd({ appStoreUrl: "https://apps.apple.com/x", socials: { facebook: "https://facebook.com/dealgo" } }),
    );
    expect(full).toContain('"sameAs":["https://facebook.com/dealgo"]');
    expect(full).toContain('"installUrl":["https://apps.apple.com/x"]');
  });

  it("partner policy publishes no commission numbers and has vi+en", () => {
    for (const loc of ["vi", "en"] as const) {
      const text = JSON.stringify(PARTNER_POLICY[loc]);
      expect(text).not.toMatch(/\d+\s?%/);
      expect(PARTNER_POLICY[loc].sections).toHaveLength(8);
    }
  });
});
