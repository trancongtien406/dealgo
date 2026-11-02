import { describe, expect, it } from "vitest";
import { emailStep, publishErrors } from "@/features/legal-consent/email-step";

describe("legal email two-step send (t82u)", () => {
  const fresh = { emailStatus: "NONE", emailSentCount: 0, emailRecipients: null };

  it("needs a preview before the send button", () => {
    expect(emailStep(fresh, null)).toEqual({ kind: "preview" });
  });

  it("confirms the exact previewed count", () => {
    expect(emailStep(fresh, 42)).toEqual({ kind: "confirm", count: 42 });
    expect(emailStep(fresh, 0)).toEqual({ kind: "empty" });
  });

  it("never offers a second send", () => {
    expect(emailStep({ emailStatus: "SENDING", emailSentCount: 100, emailRecipients: 250 }, 250)).toEqual({ kind: "done", label: "100/250 email" });
  });

  it("validates the publish form", () => {
    expect(publishErrors({ changelog: "ab", audienceRoles: ["CUSTOMER"] })).toMatch(/3 ký tự/);
    expect(publishErrors({ changelog: "Cập nhật phí", audienceRoles: [] })).toMatch(/nhóm/);
    expect(publishErrors({ changelog: "Cập nhật phí", audienceRoles: ["DRIVER"] })).toBeNull();
  });
});
