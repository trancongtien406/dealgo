import { Controller, Get, Inject, UseGuards } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  MAPS_CAPABILITY_SETTING,
  MapsProviderSettings,
  type MapsCapability,
} from '../../integrations/maps/maps-provider-settings.js';
import type { AppEnv } from '../../platform/config/index.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';

const CAPABILITIES: MapsCapability[] = ['search', 'reverse', 'route'];

export type MapsProvidersView = {
  googleConfigured: boolean;
  /** The env-configured base provider every capability falls back to (e.g. mapbox). */
  primary: { maps: string; routing: string };
  /** Map background tiles are not switchable: Admin and app draw Mapbox/OSM tiles. */
  tiles: 'mapbox';
  capabilities: Array<{
    capability: MapsCapability;
    key: string;
    /** The admin's stored choice. */
    chosen: 'mapbox' | 'google';
    /** What is actually used (google only with GOOGLE_MAPS_API_KEY). */
    effective: 'mapbox' | 'google';
    updatedAt: string | null;
    updatedByUserId: string | null;
  }>;
};

/**
 * Admin › Cài đặt › Bản đồ: which provider serves search / reverse geocode / routing.
 * Changes go through PATCH /v1/ops/platform-settings/:key (settings.write, audited).
 */
@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/maps-providers')
@UseGuards(OpsPermissionGuard)
export class OpsMapsProvidersController {
  constructor(
    private readonly settings: PlatformSettingsService,
    @Inject(MapsProviderSettings) private readonly providers: MapsProviderSettings,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Map provider per capability (mapbox | google) and whether Google is configured.' })
  async get(): Promise<MapsProvidersView> {
    const views = await this.settings.list();
    const byKey = new Map(views.map((v) => [v.key, v]));
    const capabilities = await Promise.all(
      CAPABILITIES.map(async (capability) => {
        const key = MAPS_CAPABILITY_SETTING[capability];
        const view = byKey.get(key);
        return {
          capability,
          key,
          chosen: await this.providers.chosen(capability),
          effective: await this.providers.effective(capability),
          updatedAt: view?.source === 'db' ? view.updatedAt : null,
          updatedByUserId: view?.updatedByUserId ?? null,
        };
      }),
    );
    return {
      googleConfigured: this.providers.googleConfigured(),
      primary: {
        maps: (this.config.get('MAPS_PROVIDER', { infer: true }) ?? 'mock').toLowerCase(),
        routing: (this.config.get('ROUTING_PROVIDER', { infer: true }) ?? 'none').toLowerCase(),
      },
      tiles: 'mapbox',
      capabilities,
    };
  }
}
