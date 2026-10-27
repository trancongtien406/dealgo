import { describe, expect, it } from "vitest";
import {
  adjustmentKindLabel,
  checkDriverPayment,
  debtUsagePercent,
  parseDriverBalance,
} from "./driver-balance";

describe("driver balance (cash model)", () => {
  it("parses numbers given as strings and defaults missing fields", () => {
    const b = parseDriverBalance({
      feesVnd: "12000",
      adjustmentsVnd: -3000,
      amountVnd: 9000,
      limitVnd: 200000,
      blocked: false,
      adjustments: [
        {
          id: "a",
          kind: "CUSTOMER_FEE_PAYOUT",
          amountVnd: "-3000",
          occurredAt: "2026-10-26T05:00:00.000Z",
        },
      ],
    });
    expect(b.feesVnd).toBe(12000);
    expect(b.settledThrough).toBeNull();
    expect(b.adjustments[0]?.amountVnd).toBe(-3000);
    expect(parseDriverBalance(null).adjustments).toEqual([]);
  });

  it("labels known kinds in Vietnamese and passes unknown through", () => {
    expect(adjustmentKindLabel("FOOD_DISCOUNT_REIMBURSED")).toMatch(/voucher/);
    expect(adjustmentKindLabel("X")).toBe("X");
  });

  it("computes limit usage, capped and zero when disabled", () => {
    expect(debtUsagePercent({ amountVnd: 100000, limitVnd: 200000 })).toBe(50);
    expect(debtUsagePercent({ amountVnd: 300000, limitVnd: 200000 })).toBe(100);
    expect(debtUsagePercent({ amountVnd: 100000, limitVnd: 0 })).toBe(0);
    expect(debtUsagePercent({ amountVnd: -5000, limitVnd: 200000 })).toBe(0);
  });
});

describe("driver payment + cancel rate", () => {
  it("validates direction and amount bounds", () => {
    expect(checkDriverPayment({ direction: "DRIVER_PAID", amountVnd: "50000" })).toEqual({
      ok: true,
      value: { direction: "DRIVER_PAID", amountVnd: 50000 },
    });
    expect(checkDriverPayment({ direction: "X", amountVnd: 5000 }).ok).toBe(false);
    expect(checkDriverPayment({ direction: "DEALGO_PAID", amountVnd: 999 }).ok).toBe(false);
  });

  it("parses the cancel rate or null", () => {
    expect(parseDriverBalance({}).cancelRate).toBeNull();
    expect(
      parseDriverBalance({ cancelRate: { percent: "25", warn: true, windowDays: 7 } }).cancelRate,
    ).toMatchObject({ percent: 25, warn: true, windowDays: 7 });
  });
});
