import { describe, expect, it } from "vitest";
import { formatSubmittedAt } from "@/features/catalog-moderation/api";

describe("catalog moderation submittedAt", () => {
  it("formats the ISO submission time in Vietnam time", () => {
    const shown = formatSubmittedAt("2026-10-25T18:30:00.000Z");
    expect(shown).toContain("26/10/2026");
    expect(shown).toContain("01:30");
  });
  it("keeps legacy labels and blanks", () => {
    expect(formatSubmittedAt("Hôm nay")).toBe("Hôm nay");
    expect(formatSubmittedAt(undefined)).toBe("—");
  });
});
