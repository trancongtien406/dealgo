import { describe, expect, it } from "vitest";
import { reportsSearch } from "./api";
import { mapNestReport } from "./mappers";

describe("reports mapping", () => {
  it("maps totals and per-day series from the Nest report", () => {
    const view = mapNestReport({
      from: "2026-10-01",
      to: "2026-10-02",
      timezone: "Asia/Ho_Chi_Minh",
      generatedAt: "2026-10-02T10:00:00.000Z",
      totals: {
        ridesCompleted: 3,
        ridesCancelled: 1,
        foodDelivered: 2,
        foodCancelled: 1,
        revenueVnd: 350_000,
        commissionVnd: 55_000,
        rideRevenueVnd: 150_000,
        foodRevenueVnd: 200_000,
      },
      daily: [
        { day: "2026-10-01", ridesCompleted: 0, ridesCancelled: 0, foodDelivered: 2, foodCancelled: 1, revenueVnd: 200_000, commissionVnd: 40_000 },
        { day: "2026-10-02", ridesCompleted: 3, ridesCancelled: 1, foodDelivered: 0, foodCancelled: 0, revenueVnd: 150_000, commissionVnd: 15_000 },
      ],
    });
    expect(view.revenueVnd).toBe(350_000);
    expect(view.commissionVnd).toBe(55_000);
    expect(view.services.map((s) => s.value)).toEqual([3, 2, 1, 1]);
    expect(view.trendDays).toEqual(["01/10", "02/10"]);
    expect(view.trendSeries[2]?.values).toEqual([1, 1]);
  });

  it("builds the query string from the selected range only", () => {
    expect(reportsSearch({ from: "2026-10-01", to: "2026-10-07" })).toBe("?from=2026-10-01&to=2026-10-07");
    expect(reportsSearch({ from: null, to: null })).toBe("");
    expect(reportsSearch()).toBe("");
  });
});
