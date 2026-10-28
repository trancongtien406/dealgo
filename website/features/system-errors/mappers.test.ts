import { describe, expect, it } from "vitest";
import { issueListQuery } from "@/features/system-errors/api";
import {
  frameLocation,
  navBadgeLabel,
  projectForTab,
  sparklinePoints,
  tabForProject,
} from "@/features/system-errors/mappers";

describe("system-errors mappers", () => {
  it("maps project tabs both ways", () => {
    expect(projectForTab("Mobile")).toBe("flutter");
    expect(projectForTab("Tất cả")).toBeNull();
    expect(tabForProject("dealgo-web")).toBe("Web");
    expect(tabForProject("unknown")).toBe("Tất cả");
  });

  it("hides the nav badge at zero/unknown and caps it", () => {
    expect(navBadgeLabel(0)).toBeUndefined();
    expect(navBadgeLabel(null)).toBeUndefined();
    expect(navBadgeLabel(undefined)).toBeUndefined();
    expect(navBadgeLabel(4)).toBe("4");
    expect(navBadgeLabel(250)).toBe("99+");
  });

  it("builds sparkline points scaled to the max", () => {
    expect(sparklinePoints([], 60, 16)).toBe("0,16 60,16");
    expect(sparklinePoints([0, 2, 4], 60, 16)).toBe("0,16 30,8.5 60,1");
  });

  it("formats frame locations", () => {
    expect(frameLocation({ file: "lib/a.dart", line: 12, column: 3 })).toBe(
      "lib/a.dart:12:3",
    );
    expect(frameLocation({ file: "a.ts", line: 5, column: null })).toBe(
      "a.ts:5",
    );
    expect(frameLocation({ file: null, line: 1, column: 1 })).toBe("—");
  });

  it("builds the list query with only set filters", () => {
    expect(
      issueListQuery({
        project: "flutter",
        environment: null,
        status: "unresolved",
        period: "14d",
        sort: "freq",
        q: "  boom ",
        cursor: null,
      }),
    ).toBe("project=flutter&status=unresolved&period=14d&sort=freq&q=boom");
  });
});
