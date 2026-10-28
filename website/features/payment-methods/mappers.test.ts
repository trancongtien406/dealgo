import { describe, expect, it } from "vitest";
import { configStatus, diffPatches, draftFromMethod } from "@/features/payment-methods/mappers";
import type { OpsPaymentMethod } from "@/features/payment-methods/types";

const base: OpsPaymentMethod = {
  code: "MOMO",
  label: "MoMo",
  group: "WALLET",
  provider: "momo",
  adapterKind: "REAL",
  requiredEnv: ["MOMO_PARTNER_CODE"],
  configured: true,
  services: { BIKE: false, CAR: false, FOOD: false },
  sortOrder: 10,
  unsupportedReason: null,
  availableFor: { BIKE: false, CAR: false, FOOD: false },
  locked: false,
};

describe("payment-methods mappers", () => {
  it("returns no patches when nothing changed", () => {
    expect(diffPatches([base], { MOMO: draftFromMethod(base) })).toEqual([]);
  });

  it("emits only changed fields", () => {
    const d = draftFromMethod(base);
    d.services.FOOD = true;
    d.unsupportedReason = "  Đang xin giấy phép ";
    expect(diffPatches([base], { MOMO: d })).toEqual([
      { code: "MOMO", services: { FOOD: true }, unsupportedReason: "Đang xin giấy phép" },
    ]);
  });

  it("never patches locked CASH", () => {
    const cash = { ...base, code: "CASH", locked: true };
    const d = draftFromMethod(cash);
    d.sortOrder = 99;
    expect(diffPatches([cash], { CASH: d })).toEqual([]);
  });

  it("clears reason to null", () => {
    const m = { ...base, unsupportedReason: "x" };
    const d = draftFromMethod(m);
    d.unsupportedReason = "";
    expect(diffPatches([m], { MOMO: d })[0]?.unsupportedReason).toBeNull();
  });

  it("describes config status", () => {
    expect(configStatus(base, true).label).toBe("Đã cấu hình");
    expect(configStatus(base, false).tone).toBe("danger");
    expect(configStatus({ ...base, configured: false }, true).tone).toBe("food");
    expect(configStatus({ ...base, adapterKind: "STUB" }, true).label).toContain("stub");
  });
});
