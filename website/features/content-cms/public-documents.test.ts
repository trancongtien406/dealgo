import { describe, expect, it } from "vitest";
import { fallbackLegalPage, fallbackSupportPage, shownContact } from "./public-documents";
import { localeFromLang } from "./types";

describe("public page helpers", () => {
  it("hides empty and placeholder contacts", () => {
    expect(shownContact("")).toBeNull();
    expect(shownContact("[Hotline]")).toBeNull();
    expect(shownContact(" 1900 1234 ")).toBe("1900 1234");
  });

  it("maps lang to locale, defaulting to vi", () => {
    expect(localeFromLang("en")).toBe("en");
    expect(localeFromLang(["en", "vi"])).toBe("en");
    expect(localeFromLang("fr")).toBe("vi");
    expect(localeFromLang(undefined)).toBe("vi");
  });

  it("offline fallbacks carry no contact data", () => {
    expect(fallbackSupportPage("vi").content.email).toBe("");
    expect(fallbackLegalPage("terms", "en").title).toBe("Terms of Use");
  });
});
