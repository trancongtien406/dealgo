import { Injectable } from '@nestjs/common';
import {
  PlatformSettingsService,
  type PublicSiteConfig,
  readPublicSiteConfig,
} from '../../platform/settings/index.js';

const KEY = 'PUBLIC_SITE_CONFIG';

/** Public website links stored as the PUBLIC_SITE_CONFIG platform setting (audited on patch). */
@Injectable()
export class SiteConfigService {
  constructor(private readonly settings: PlatformSettingsService) {}

  async get(): Promise<PublicSiteConfig> {
    try {
      return readPublicSiteConfig(await this.settings.getJson<unknown>(KEY));
    } catch {
      return {};
    }
  }

  async update(
    config: unknown,
    reason: string,
    actorUserId: string,
  ): Promise<PublicSiteConfig> {
    // Validation (https + allowed hosts) and the SETTINGS_UPDATE audit row live in patch().
    const view = await this.settings.patch(
      KEY,
      JSON.stringify(config ?? {}),
      reason,
      actorUserId,
    );
    return readPublicSiteConfig(JSON.parse(view.value));
  }
}
