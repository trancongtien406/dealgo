import { describe, expect, it } from "vitest";
import { kycApproveButtonLabel } from "./components/kyc-case-detail";

// Regression: after approving, the button read "Chưa đủ điều kiện duyệt".
describe("kycApproveButtonLabel", () => {
  it("shows decided states", () => {
    expect(
      kycApproveButtonLabel({
        status: "APPROVED",
        approvedNow: false,
        ready: false,
      }),
    ).toBe("Đã duyệt");
    expect(
      kycApproveButtonLabel({
        status: "PENDING",
        approvedNow: true,
        ready: false,
      }),
    ).toBe("Đã duyệt");
    expect(
      kycApproveButtonLabel({
        status: "REJECTED",
        approvedNow: false,
        ready: false,
      }),
    ).toBe("Đã từ chối");
  });
  it("keeps pending states", () => {
    expect(
      kycApproveButtonLabel({
        status: "PENDING",
        approvedNow: false,
        ready: true,
      }),
    ).toBe("Duyệt hồ sơ");
    expect(
      kycApproveButtonLabel({
        status: "PENDING",
        approvedNow: false,
        ready: false,
      }),
    ).toBe("Chưa đủ điều kiện duyệt");
  });
});
