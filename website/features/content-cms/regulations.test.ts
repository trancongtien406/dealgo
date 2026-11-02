import { describe, expect, it } from "vitest";
import { LEGAL_SLUG_LABELS } from "@/features/legal-consent/types";
import { PUBLIC_ROUTES } from "@/lib/seo/site";
import { CONTENT_CMS_TAB_SLUG, CONTENT_CMS_TABS, PUBLIC_PAGE_HREF } from "./constants";
import { fallbackLegalPage } from "./public-documents";
import { PUBLIC_PAGE_SLUGS } from "./types";

describe("pt5u: Quy chế sử dụng is managed like terms/privacy", () => {
  it("has its own CMS tab, public URL and consent label", () => {
    expect(PUBLIC_PAGE_SLUGS).toContain("regulations");
    expect(CONTENT_CMS_TABS).toContain("Quy chế sử dụng");
    expect(CONTENT_CMS_TAB_SLUG["Quy chế sử dụng"]).toBe("regulations");
    expect(PUBLIC_PAGE_HREF.regulations).toBe("/regulations");
    expect(LEGAL_SLUG_LABELS.regulations).toMatch(/Quy chế sử dụng/);
    expect(PUBLIC_ROUTES).toContain("/regulations");
  });

  it("has an offline fallback in both locales", () => {
    expect(fallbackLegalPage("regulations", "vi").title).toBe("Quy chế sử dụng");
    expect(fallbackLegalPage("regulations", "en").title).toBe("Regulations");
  });
});
