import { describe, expect, it } from "vitest";
import { cancelActorLabel } from "@/lib/cancel-actor";

describe("cancelActorLabel (DEC-PROD-035)", () => {
  it("labels each actor and hides unknown / missing values", () => {
    expect(cancelActorLabel("CUSTOMER")).toBe("Khách hàng huỷ");
    expect(cancelActorLabel("DRIVER")).toBe("Tài xế huỷ");
    expect(cancelActorLabel("MERCHANT")).toBe("Quán huỷ / từ chối");
    expect(cancelActorLabel("OPS")).toBe("Ops huỷ");
    expect(cancelActorLabel("SYSTEM")).toBe("Hệ thống huỷ");
    expect(cancelActorLabel(null)).toBeNull();
    expect(cancelActorLabel(undefined)).toBeNull();
    expect(cancelActorLabel("ROBOT")).toBeNull();
  });
});
