export type AppPlatform = "ios" | "android";

export type AppPlatformPolicy = {
  minBuild: number;
  latestBuild: number;
  latestVersion: string;
  storeUrl: string;
};

export type AppVersionPolicy = Record<AppPlatform, AppPlatformPolicy> & {
  message: string;
  enforceApi: boolean;
};

export const APP_PLATFORM_LABELS: Record<AppPlatform, string> = { ios: "iOS (App Store)", android: "Android (Google Play)" };
