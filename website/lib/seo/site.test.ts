import { afterEach, describe, expect, it, vi } from "vitest";
import { landingJsonLd, PUBLIC_ROUTES, siteUrl } from "./site";

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
});
