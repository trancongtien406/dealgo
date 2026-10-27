import { describe, expect, it } from "vitest";
import {
  foodCancelReasonLabel,
  mapFoodOrderChange,
} from "@/features/food-orders/mappers";

describe("Merchant edit in the ops detail", () => {
  it("is null without a change", () => {
    expect(mapFoodOrderChange(null)).toBeNull();
    expect(mapFoodOrderChange(undefined)).toBeNull();
  });

  it("summarises lines, totals, status and reason", () => {
    const summary = mapFoodOrderChange({
      id: "c1",
      status: "REJECTED",
      reasonCode: "OUT_OF_STOCK",
      note: " Hết nước ngọt ",
      lines: [
        {
          lineId: "l1",
          name: "Nước ngọt",
          unitPriceVnd: 10_000,
          fromQuantity: 2,
          toQuantity: 0,
        },
        {
          lineId: "l2",
          name: "Cơm gà",
          unitPriceVnd: 40_000,
          fromQuantity: 2,
          toQuantity: 1,
        },
      ],
      oldSubtotalVnd: 100_000,
      newSubtotalVnd: 40_000,
      newTotalVnd: 55_000,
      expiresAt: "2026-10-26T07:05:00.000Z",
      respondedAt: "2026-10-26T07:02:00.000Z",
      createdAt: "2026-10-26T07:00:00.000Z",
    });
    expect(summary).toMatchObject({
      statusTone: "danger",
      reason: "Hết món — Hết nước ngọt",
      lines: ["Nước ngọt: 2 → 0 (bỏ món)", "Cơm gà: 2 → 1"],
      newTotalVnd: 55_000,
      createdAt: "14:00",
      answerBy: "14:05",
      respondedAt: "14:02",
    });
  });

  it("labels the change cancel reasons", () => {
    expect(foodCancelReasonLabel({ code: "CHANGE_REJECTED", note: null })).toBe(
      "Khách không đồng ý quán sửa đơn",
    );
    expect(foodCancelReasonLabel({ code: "CHANGE_EXPIRED", note: null })).toBe(
      "Khách không xác nhận quán sửa đơn",
    );
  });
});
