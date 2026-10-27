import { describe, expect, it } from "vitest";
import { checkPublicPageDraftBody, checkPublicPageParams } from "./ops-public-page-body";

describe("checkPublicPageParams", () => {
  it("accepts known slugs and locales only", () => {
    expect(checkPublicPageParams("privacy", "vi").ok).toBe(true);
    expect(checkPublicPageParams("support", "en").ok).toBe(true);
    expect(checkPublicPageParams("about", "vi").ok).toBe(false);
    expect(checkPublicPageParams("terms", "fr").ok).toBe(false);
  });
});

describe("checkPublicPageDraftBody", () => {
  it("normalises title, summary and effective date", () => {
    const r = checkPublicPageDraftBody({
      title: "  Điều khoản ",
      summary: " ",
      effectiveAt: "2026-11-01",
      content: { badge: "", sections: [] },
    });
    expect(r).toEqual({
      ok: true,
      value: {
        title: "Điều khoản",
        summary: null,
        effectiveAt: "2026-11-01T00:00:00.000Z",
        content: { badge: "", sections: [] },
      },
    });
  });

  it("rejects missing title, bad dates and non-object content", () => {
    expect(checkPublicPageDraftBody({ title: "", content: {} }).ok).toBe(false);
    expect(checkPublicPageDraftBody({ title: "x", effectiveAt: "nope", content: {} }).ok).toBe(false);
    expect(checkPublicPageDraftBody({ title: "x", content: [] }).ok).toBe(false);
    expect(checkPublicPageDraftBody(null).ok).toBe(false);
  });
});
