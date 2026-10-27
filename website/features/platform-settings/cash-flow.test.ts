import { describe, expect, it } from "vitest";
import {
  CASH_FLOW_KEYS,
  cashFlowUnit,
  commissionOf,
  foodExample,
  formatVnd,
  platformFundedDiscount,
  readCashFlowSettings,
  rideExample,
} from "@/features/platform-settings/cash-flow";

describe("cash-flow maths (mirrors backend rounding)", () => {
  it("splits a ride fare by the vehicle-class commission", () => {
    expect(rideExample({ fareVnd: 50_000, commissionPercent: 10 })).toEqual({
      customerPaysVnd: 50_000,
      driverCollectsCashVnd: 50_000,
      commissionVnd: 5_000,
      driverKeepsVnd: 45_000,
      driverOwesDealGoVnd: 5_000,
      previousDriverGetsVnd: 0,
      dealGoEarnsVnd: 5_000,
    });
    // Carried late-cancel fee passes through, never commissioned.
    const withFee = rideExample({ fareVnd: 80_000, commissionPercent: 15, carriedCancelFeeVnd: 10_000 });
    expect(withFee.customerPaysVnd).toBe(90_000);
    expect(withFee.commissionVnd).toBe(12_000);
    expect(withFee.driverKeepsVnd).toBe(68_000);
    expect(withFee.driverOwesDealGoVnd).toBe(22_000);
    expect(withFee.previousDriverGetsVnd).toBe(10_000);
  });

  it("rounds half up like splitFare and clamps bad percents", () => {
    expect(commissionOf(33_335, 12.5)).toBe(4_167); // 4166.875
    expect(commissionOf(10_005, 10)).toBe(1_001); // 1000.5 → 1001
    expect(commissionOf(50_000, 0)).toBe(0);
    expect(commissionOf(50_000, 150)).toBe(50_000);
    expect(commissionOf(-5, 10)).toBe(0);
  });

  it("splits who pays a voucher", () => {
    expect(platformFundedDiscount(10_000, "PLATFORM", 50)).toBe(10_000);
    expect(platformFundedDiscount(10_000, "MERCHANT", 50)).toBe(0);
    expect(platformFundedDiscount(10_000, "SHARED", 30)).toBe(3_000);
    expect(platformFundedDiscount(0, "SHARED", 30)).toBe(0);
  });

  it("works through a food order end to end", () => {
    const food = foodExample({
      subtotalVnd: 100_000,
      deliveryFeeVnd: 20_000,
      discountVnd: 10_000,
      sponsor: "SHARED",
      merchantPercent: 20,
      driverPercent: 10,
      sharedPlatformPercent: 50,
    });
    expect(food).toEqual({
      customerPaysVnd: 110_000,
      platformFundedVnd: 5_000,
      merchantFundedVnd: 5_000,
      driverPaysMerchantVnd: 95_000,
      merchantCommissionVnd: 20_000,
      merchantKeepsVnd: 75_000,
      driverCommissionVnd: 2_000,
      driverKeepsVnd: 18_000,
      driverOwesDealGoVnd: -3_000,
      dealGoEarnsVnd: 17_000,
    });
    // Driver cash check: collects 110k, pays store 95k, gets 5k back, owes 2k → keeps 18k.
    expect(110_000 - 95_000 + 5_000 - 2_000).toBe(food.driverKeepsVnd);
  });

  it("caps the store commission at the subtotal and keeps the driver whole at 0%", () => {
    const food = foodExample({
      subtotalVnd: 50_000,
      deliveryFeeVnd: 15_000,
      discountVnd: 0,
      sponsor: "PLATFORM",
      merchantPercent: 100,
      driverPercent: 0,
      sharedPlatformPercent: 0,
    });
    expect(food.merchantCommissionVnd).toBe(50_000);
    expect(food.driverKeepsVnd).toBe(15_000);
    expect(food.customerPaysVnd).toBe(65_000);
  });

  it("reads settings rows defensively and labels units", () => {
    const settings = readCashFlowSettings([
      { key: "RIDE_COMMISSION_BIKE_PERCENT", value: "10" },
      { key: "RIDE_COMMISSION_CAR_PERCENT", value: "abc" },
      { key: "MERCHANT_SETTLEMENT_CYCLE_DAYS", value: " 7 " },
    ]);
    expect(settings.rideBikePercent).toBe(10);
    expect(settings.rideCarPercent).toBe(0);
    expect(settings.settlementCycleDays).toBe(7);
    expect(settings.merchantPercent).toBe(0);
    expect(CASH_FLOW_KEYS.has("FOOD_DRIVER_COMMISSION_PERCENT")).toBe(true);
    expect(CASH_FLOW_KEYS.has("DRIVER_DEBT_LIMIT_VND")).toBe(true);
    expect(cashFlowUnit("RIDE_CANCEL_FEE_CAR_VND")).toBe("đ");
    expect(cashFlowUnit("MERCHANT_SETTLEMENT_CYCLE_DAYS")).toBe("ngày");
    expect(formatVnd(-3000)).toMatch(/^−3.000đ$/);
  });
});
