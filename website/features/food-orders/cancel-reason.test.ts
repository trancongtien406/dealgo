import { describe, expect, it } from "vitest";
import { foodCancelReasonLabel } from "@/features/food-orders/mappers";

describe("food cancel reason label", () => {
  it("labels known codes, falls back to OTHER and appends notes", () => {
    expect(foodCancelReasonLabel(null)).toBeNull();
    expect(foodCancelReasonLabel({ code: "OUT_OF_STOCK", note: null })).toBe(
      "Hết món",
    );
    expect(foodCancelReasonLabel({ code: "NEW", note: " Bếp hỏng " })).toBe(
      "Lý do khác — Bếp hỏng",
    );
  });
});
