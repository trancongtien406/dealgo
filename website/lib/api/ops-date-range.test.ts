import { describe, expect, it } from "vitest";
import {
  normalizeOpsDateRange,
  opsDateRangeFromSearch,
  opsDayKey,
  setOpsDateRange,
} from "@/lib/api/ops-date-range";

describe("ops date range", () => {
  it("accepts only real YYYY-MM-DD days", () => {
    expect(opsDayKey("2026-10-26")).toBe("2026-10-26");
    expect(opsDayKey(" 2026-10-26 ")).toBe("2026-10-26");
    expect(opsDayKey("2026-02-30")).toBeNull();
    expect(opsDayKey("26/10/2026")).toBeNull();
    expect(opsDayKey("")).toBeNull();
    expect(opsDayKey(null)).toBeNull();
  });

  it("drops bad bounds and swaps a reversed range", () => {
    expect(normalizeOpsDateRange({ from: "2026-10-27", to: "2026-10-20" })).toEqual({
      from: "2026-10-20",
      to: "2026-10-27",
    });
    expect(normalizeOpsDateRange({ from: "x", to: "2026-10-20" })).toEqual({
      to: "2026-10-20",
    });
    expect(normalizeOpsDateRange({ from: null, to: null })).toEqual({});
  });

  it("round-trips through URLSearchParams", () => {
    const search = setOpsDateRange(new URLSearchParams({ page: "1" }), {
      from: "2026-10-20",
      to: "2026-10-26",
    });
    expect(search.toString()).toBe("page=1&from=2026-10-20&to=2026-10-26");
    expect(opsDateRangeFromSearch(search)).toEqual({
      from: "2026-10-20",
      to: "2026-10-26",
    });
    expect(setOpsDateRange(new URLSearchParams(), {}).toString()).toBe("");
  });
});
