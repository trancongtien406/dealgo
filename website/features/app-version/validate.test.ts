import { describe, expect, it } from "vitest";
import { draftToPolicy, platformErrors, toPlatformDraft } from "@/features/app-version/validate";

describe("app version policy form (t82u)", () => {
  it("empty draft = no rule, no errors", () => {
    const d = toPlatformDraft(undefined);
    expect(platformErrors("ios", d)).toEqual({});
    expect(draftToPolicy({ ios: d, android: d }, "", true).ios.minBuild).toBe(0);
  });

  it("requires a store link when blocking and checks the host", () => {
    expect(platformErrors("ios", { ...toPlatformDraft(undefined), minBuild: "20" }).storeUrl).toMatch(/Cần link/);
    expect(
      platformErrors("android", { minBuild: "20", latestBuild: "", latestVersion: "", storeUrl: "https://apps.apple.com/x" }).storeUrl,
    ).toMatch(/play.google.com/);
  });

  it("min cannot exceed latest", () => {
    expect(
      platformErrors("ios", { minBuild: "25", latestBuild: "24", latestVersion: "", storeUrl: "https://apps.apple.com/x" }).minBuild,
    ).toMatch(/không được lớn hơn/);
  });

  it("maps a draft to the API payload", () => {
    const ios = { minBuild: "20", latestBuild: "24", latestVersion: " 1.0.1 ", storeUrl: "https://apps.apple.com/app/id1" };
    expect(draftToPolicy({ ios, android: toPlatformDraft(undefined) }, " Hi ", false)).toEqual({
      ios: { minBuild: 20, latestBuild: 24, latestVersion: "1.0.1", storeUrl: "https://apps.apple.com/app/id1" },
      android: { minBuild: 0, latestBuild: 0, latestVersion: "", storeUrl: "" },
      message: "Hi",
      enforceApi: false,
    });
  });
});
