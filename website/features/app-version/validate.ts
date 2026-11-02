import type { AppPlatform, AppPlatformPolicy, AppVersionPolicy } from "@/features/app-version/types";

const HOSTS: Record<AppPlatform, string[]> = {
  ios: ["apps.apple.com", "itunes.apple.com", "testflight.apple.com"],
  android: ["play.google.com"],
};

export type PlatformDraft = { minBuild: string; latestBuild: string; latestVersion: string; storeUrl: string };

export function toPlatformDraft(p: AppPlatformPolicy | undefined): PlatformDraft {
  return {
    minBuild: p && p.minBuild > 0 ? String(p.minBuild) : "",
    latestBuild: p && p.latestBuild > 0 ? String(p.latestBuild) : "",
    latestVersion: p?.latestVersion ?? "",
    storeUrl: p?.storeUrl ?? "",
  };
}

function build(v: string): number | null {
  const s = v.trim();
  if (!s) return 0;
  return /^\d{1,9}$/.test(s) ? Number(s) : null;
}

/** Mirrors backend normalizeAppVersionPolicy (server stays authoritative). */
export function platformErrors(platform: AppPlatform, d: PlatformDraft): Partial<Record<keyof PlatformDraft, string>> {
  const errors: Partial<Record<keyof PlatformDraft, string>> = {};
  const min = build(d.minBuild);
  const latest = build(d.latestBuild);
  if (min === null) errors.minBuild = "Số build là số nguyên ≥ 0.";
  if (latest === null) errors.latestBuild = "Số build là số nguyên ≥ 0.";
  if (min !== null && latest !== null && latest > 0 && min > latest) errors.minBuild = "Build tối thiểu không được lớn hơn build mới nhất.";
  const url = d.storeUrl.trim();
  if (url) {
    try {
      const u = new URL(url);
      if (u.protocol !== "https:" || !HOSTS[platform].includes(u.hostname)) errors.storeUrl = `Link phải là https trên ${HOSTS[platform].join(" / ")}.`;
    } catch {
      errors.storeUrl = "Link không hợp lệ.";
    }
  } else if (min !== null && min > 0) {
    errors.storeUrl = "Cần link cửa hàng khi bật bắt buộc cập nhật.";
  }
  return errors;
}

export function draftToPolicy(
  d: Record<AppPlatform, PlatformDraft>,
  message: string,
  enforceApi: boolean,
): AppVersionPolicy {
  const one = (p: PlatformDraft): AppPlatformPolicy => ({
    minBuild: build(p.minBuild) ?? 0,
    latestBuild: build(p.latestBuild) ?? 0,
    latestVersion: p.latestVersion.trim(),
    storeUrl: p.storeUrl.trim(),
  });
  return { ios: one(d.ios), android: one(d.android), message: message.trim(), enforceApi };
}
