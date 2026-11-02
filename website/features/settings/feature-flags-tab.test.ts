import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { featureFlagRows } from "@/features/platform-settings/mappers";

// Regression: the "Feature flags" tab showed hard-coded demo
// flags ("Giao diện điều phối bản đồ V2 100%") instead of the real KYC/KYB switches.
describe("settings feature flags tab", () => {
  it("keeps only the real boolean platform switches", () => {
    const rows = [
      { key: "ONBOARDING_DRIVER_KYC_REQUIRED", value: "false" },
      { key: "ONBOARDING_MERCHANT_KYB_REQUIRED", value: "true" },
      { key: "KYC_AUTO_APPROVE_DRIVER", value: "false" },
      { key: "KYC_AUTO_APPROVE_MERCHANT", value: "false" },
      { key: "RIDE_MIN_FARE_VND", value: "15000" },
    ];
    expect(featureFlagRows(rows).map((r) => r.key)).toEqual([
      "ONBOARDING_DRIVER_KYC_REQUIRED",
      "ONBOARDING_MERCHANT_KYB_REQUIRED",
      "KYC_AUTO_APPROVE_DRIVER",
      "KYC_AUTO_APPROVE_MERCHANT",
    ]);
  });

  it("offers the email verification switch as Bật / Tắt", () => {
    const rows = [
      { key: "AUTH_EMAIL_VERIFICATION_REQUIRED", value: "true" },
      { key: "RIDE_MIN_FARE_VND", value: "15000" },
    ];
    expect(featureFlagRows(rows).map((r) => r.key)).toEqual([
      "AUTH_EMAIL_VERIFICATION_REQUIRED",
    ]);
  });

  it("has no hard-coded demo flags in the board", () => {
    const src = readFileSync(
      path.resolve(__dirname, "components/settings-board.tsx"),
      "utf8",
    );
    expect(src).not.toContain("Giao diện điều phối bản đồ V2");
    expect(src).not.toContain("Thuật toán ghép cuốc thông minh");
    expect(src).toContain("pickFeatureFlags(platformRows)");
  });
});
