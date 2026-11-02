import { Injectable } from '@nestjs/common';
import {
  type AppPlatform,
  type AppUpdateVerdict,
  type AppVersionPolicy,
  appUpdateVerdict,
  PlatformSettingsService,
  readAppVersionPolicy,
} from '../../platform/settings/index.js';

const KEY = 'APP_VERSION_POLICY';

export type PublicAppVersionPolicy = {
  platform: AppPlatform | null;
  minBuild: number;
  latestBuild: number;
  latestVersion: string;
  storeUrl: string;
  message: string;
  /** Present when the caller sent its build. */
  verdict: AppUpdateVerdict | null;
  ios: AppVersionPolicy['ios'];
  android: AppVersionPolicy['android'];
};

/** t82u: APP_VERSION_POLICY platform setting (validation + audit live in PlatformSettingsService.patch). */
@Injectable()
export class AppVersionService {
  constructor(private readonly settings: PlatformSettingsService) {}

  async policy(): Promise<AppVersionPolicy> {
    try {
      return readAppVersionPolicy(await this.settings.getJson<unknown>(KEY));
    } catch {
      return readAppVersionPolicy({});
    }
  }

  async publicView(platform: AppPlatform | null, buildNumber: number | null): Promise<PublicAppVersionPolicy> {
    const policy = await this.policy();
    const p = platform ? policy[platform] : null;
    return {
      platform,
      minBuild: p?.minBuild ?? 0,
      latestBuild: p?.latestBuild ?? 0,
      latestVersion: p?.latestVersion ?? '',
      storeUrl: p?.storeUrl ?? '',
      message: policy.message,
      verdict: platform && buildNumber !== null ? appUpdateVerdict(policy, platform, buildNumber) : null,
      ios: policy.ios,
      android: policy.android,
    };
  }

  async update(policy: unknown, reason: string, actorUserId: string): Promise<AppVersionPolicy> {
    const view = await this.settings.patch(KEY, JSON.stringify(policy ?? {}), reason, actorUserId);
    return readAppVersionPolicy(JSON.parse(view.value));
  }

  /** True when an API call from this build must be rejected (APP_UPDATE_REQUIRED). */
  async blocks(platform: AppPlatform, buildNumber: number): Promise<boolean> {
    const policy = await this.policy();
    return policy.enforceApi && appUpdateVerdict(policy, platform, buildNumber) === 'REQUIRED';
  }
}
