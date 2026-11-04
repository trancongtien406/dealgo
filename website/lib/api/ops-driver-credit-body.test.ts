import { describe, expect, it } from "vitest";
import {
  DRIVER_CREDIT_REFUND_BANK_REF_MAX,
  checkDriverCreditRefund,
} from "@/lib/api/ops-driver-credit-body";

describe("ops driver credit refund BFF guard", () => {
  it("trims and forwards reason + bank reference", () => {
    expect(
      checkDriverCreditRefund({
        reason: "  Chấm dứt hợp tác  ",
        bankRef: " VCB-20261103-001234 ",
      }),
    ).toEqual({
      ok: true,
      value: { reason: "Chấm dứt hợp tác", bankRef: "VCB-20261103-001234" },
    });
  });

  it("rejects a reason shorter than the Nest DTO minimum", () => {
    expect(
      checkDriverCreditRefund({ reason: "huỷ", bankRef: "VCB-1" }).ok,
    ).toBe(false);
    expect(checkDriverCreditRefund({ reason: 123, bankRef: "VCB-1" }).ok).toBe(
      false,
    );
  });

  it("rejects a missing or oversized bank reference", () => {
    expect(
      checkDriverCreditRefund({ reason: "Chấm dứt hợp tác", bankRef: "  " }).ok,
    ).toBe(false);
    expect(
      checkDriverCreditRefund({
        reason: "Chấm dứt hợp tác",
        bankRef: "x".repeat(DRIVER_CREDIT_REFUND_BANK_REF_MAX + 1),
      }).ok,
    ).toBe(false);
  });
});
