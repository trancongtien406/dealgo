import { describe, expect, it } from "vitest";
import {
  checkStatementRange,
  defaultStatementRange,
  merchantSettlementErrorMessage,
  parseMerchantStatement,
  vnDayKey,
} from "@/lib/merchant-statement";

// 2026-10-26 18:30 UTC = 2026-10-27 01:30 ICT
const now = new Date("2026-10-26T18:30:00Z");

describe("merchant statement helpers", () => {
  it("uses Vietnam days", () => {
    expect(vnDayKey(now)).toBe("2026-10-27");
    expect(defaultStatementRange(now)).toEqual({
      from: "2026-10-20",
      to: "2026-10-26",
    });
  });

  it("validates ranges", () => {
    expect(
      checkStatementRange({ from: "2026-10-01", to: "2026-10-05" }, { now }).ok,
    ).toBe(true);
    expect(
      checkStatementRange({ from: "2026-10-05", to: "2026-10-01" }, { now }).ok,
    ).toBe(false);
    expect(
      checkStatementRange({ from: "2026-01-01", to: "2026-03-01" }, { now }).ok,
    ).toBe(false);
    expect(
      checkStatementRange({ from: "bad", to: "2026-10-01" }, { now }).ok,
    ).toBe(false);
  });

  it("only settles closed days", () => {
    const today = { from: "2026-10-25", to: "2026-10-27" };
    expect(checkStatementRange(today, { now }).ok).toBe(true);
    expect(checkStatementRange(today, { closedOnly: true, now }).ok).toBe(
      false,
    );
    expect(
      checkStatementRange(
        { from: "2026-10-25", to: "2026-10-26" },
        { closedOnly: true, now },
      ).ok,
    ).toBe(true);
  });

  it("maps backend error codes", () => {
    expect(
      merchantSettlementErrorMessage("FOOD_SETTLEMENT_OVERLAP"),
    ).toBeTruthy();
    expect(
      merchantSettlementErrorMessage("FOOD_SETTLEMENT_PERIOD_OPEN"),
    ).toBeTruthy();
    expect(merchantSettlementErrorMessage("OTHER")).toBeNull();
  });

  it("parses a statement defensively", () => {
    const s = parseMerchantStatement({
      storeId: "s1",
      from: "2026-10-20",
      to: "2026-10-26",
      commissionPercentNow: 15,
      settlementCycleDays: 7,
      totals: {
        orderCount: 2,
        grossVnd: 200000,
        cashReceivedVnd: 180000,
        commissionVnd: 30000,
        netVnd: 150000,
      },
      days: [
        {
          date: "2026-10-21",
          orderCount: 2,
          cashReceivedVnd: 180000,
          commissionVnd: 30000,
        },
      ],
      settlements: [],
      unsettledCommissionVnd: 30000,
    });
    expect(s.totals.orderCount).toBe(2);
    expect(s.totals.merchantFundedVnd).toBe(0);
    expect(s.days).toHaveLength(1);
    expect(s.unsettledCommissionVnd).toBe(30000);
    expect(s.settlementCycleDays).toBe(7);
    expect(parseMerchantStatement({}).settlementCycleDays).toBe(0);
    expect(parseMerchantStatement(null).days).toEqual([]);
  });
});
