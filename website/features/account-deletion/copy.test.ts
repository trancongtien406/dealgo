import { describe, expect, it } from "vitest";
import { ACCOUNT_DELETION_ROLES, accountDeletionCopy } from "./copy";
import { PUBLIC_ROUTES } from "@/lib/seo/site";

describe("Google Play account-deletion resource", () => {
  it("is listed as a public route", () => {
    expect(PUBLIC_ROUTES).toContain("/account-deletion");
  });

  it("keeps both locales in sync", () => {
    const vi = accountDeletionCopy("vi");
    const en = accountDeletionCopy("en");

    for (const key of [
      "inAppSteps",
      "dataItems",
      "keepItems",
      "timingItems",
      "blockersItems",
    ] as const) {
      expect(vi[key].length).toBeGreaterThan(0);
      expect(vi[key].length).toBe(en[key].length);
    }

    expect(Object.keys(vi.form.roles).sort()).toEqual(
      Object.keys(en.form.roles).sort(),
    );
    expect(Object.keys(vi.form.roles).sort()).toEqual(
      [...ACCOUNT_DELETION_ROLES].sort(),
    );
  });

  it("states what is deleted, what is kept and the wait period", () => {
    for (const locale of ["vi", "en"] as const) {
      const copy = accountDeletionCopy(locale);
      expect(copy.dataItems.join(" ")).toMatch(/email/i);
      expect(copy.keepItems.join(" ")).toMatch(/ledger|sổ cái/i);
      expect(copy.timingItems.join(" ")).toMatch(/7/);
      expect(copy.webIntro.length).toBeGreaterThan(40);
    }
  });
});
