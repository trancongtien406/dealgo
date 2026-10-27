import { describe, expect, it } from "vitest";
import { rideCancelReasonLabel } from "./ride-cancel-reason";

describe("rideCancelReasonLabel", () => {
  it("maps driver reasons, timeouts and no-show", () => {
    expect(rideCancelReasonLabel("PICKUP_TOO_FAR")).toBe("Điểm đón quá xa");
    expect(rideCancelReasonLabel("ASSIGNED_TIMEOUT")).toMatch(/hệ thống/);
    expect(rideCancelReasonLabel(null, true)).toBe("Khách không ra điểm đón");
  });
  it("returns null without a code and passes unknown codes through", () => {
    expect(rideCancelReasonLabel(null)).toBeNull();
    expect(rideCancelReasonLabel("NEW_CODE")).toBe("NEW_CODE");
  });
});
