import { describe, expect, it } from "vitest";
import {
  intentListSearchParams,
  intentStatusTone,
  parseRefundAmount,
  refundableOf,
} from "@/features/online-payments/mappers";

describe("online payments mappers", () => {
  it("computes the refundable remainder only for captured intents", () => {
    expect(refundableOf({ status: "CAPTURED", amountVnd: 100_000, refundedVnd: 30_000 })).toBe(70_000);
    expect(refundableOf({ status: "REFUND_PENDING", amountVnd: 100_000, refundedVnd: 100_000 })).toBe(0);
    expect(refundableOf({ status: "FAILED", amountVnd: 100_000, refundedVnd: 0 })).toBe(0);
  });

  it("parses partial refund amounts and caps at the refundable remainder", () => {
    expect(parseRefundAmount("50.000", 70_000)).toEqual({ ok: true, amountVnd: 50_000 });
    expect(parseRefundAmount("70 000", 70_000)).toEqual({ ok: true, amountVnd: 70_000 });
    expect(parseRefundAmount("80000", 70_000).ok).toBe(false);
    expect(parseRefundAmount("0", 70_000).ok).toBe(false);
    expect(parseRefundAmount("abc", 70_000).ok).toBe(false);
  });

  it("builds list query params without empty filters", () => {
    const params = intentListSearchParams({ status: "CAPTURED", provider: null, entityType: "RIDE", q: "  ", limit: 50 });
    expect(params.toString()).toBe("limit=50&status=CAPTURED&entityType=RIDE");
  });

  it("maps status tones", () => {
    expect(intentStatusTone("CAPTURED")).toBe("success");
    expect(intentStatusTone("FAILED")).toBe("danger");
    expect(intentStatusTone("EXPIRED")).toBe("brand");
  });
});
