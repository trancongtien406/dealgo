import { Body, Controller, Get, Header, HttpCode, HttpStatus, Post, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { PutEmailSettingsDto, PutMapKeysDto, TestEmailDto, TestMapKeysDto } from './integrations-admin.dto.js';
import { IntegrationsAdminService } from './integrations-admin.service.js';

/** Admin › Cài đặt › Email and › Bản đồ: provider credentials (encrypted, write-only) and tests. */
@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/integrations')
@UseGuards(OpsPermissionGuard)
export class OpsIntegrationsController {
  constructor(private readonly service: IntegrationsAdminService) {}

  @Get('email')
  @RequireOpsPermission('settings.write')
  @ApiOperation({ summary: 'Effective email provider config (secrets as set/unset), sources and test status.' })
  email() {
    return this.service.emailView();
  }

  @Put('email')
  @RequireOpsPermission('settings.write')
  @ApiOperation({ summary: 'Update email provider settings; null/"" clears a field. Audited with reason.' })
  updateEmail(@CurrentActor() actor: RequestActor, @Body() body: PutEmailSettingsDto) {
    return this.service.updateEmail(body, actor.userId);
  }

  @Post('email/test')
  @HttpCode(HttpStatus.OK)
  @RequireOpsPermission('settings.write')
  @ApiOperation({ summary: 'Send a test email with the saved config; a pass unlocks email login.' })
  testEmail(@CurrentActor() actor: RequestActor, @Body() body: TestEmailDto) {
    return this.service.testEmail(body.to, body.reason, actor.userId);
  }

  @Get('maps')
  @RequireOpsPermission('settings.write')
  @ApiOperation({ summary: 'Map keys: set/unset, source (admin/env) and last 4 characters.' })
  maps() {
    return this.service.mapKeysView();
  }

  @Put('maps')
  @RequireOpsPermission('settings.write')
  @ApiOperation({ summary: 'Replace or clear map keys (encrypted). Audited with reason.' })
  updateMaps(@CurrentActor() actor: RequestActor, @Body() body: PutMapKeysDto) {
    return this.service.updateMapKeys(body, actor.userId);
  }

  @Post('maps/test')
  @HttpCode(HttpStatus.OK)
  @RequireOpsPermission('settings.write')
  @ApiOperation({ summary: 'Check each effective map key against Mapbox / Google.' })
  testMaps(@CurrentActor() actor: RequestActor, @Body() body: TestMapKeysDto) {
    return this.service.testMapKeys(body.reason, actor.userId);
  }
}

/** Runtime client config for app and web (public values only). */
@ApiTags('public')
@Controller('v1/public/client-config')
@UseGuards(ThrottlerGuard)
export class PublicClientConfigController {
  constructor(private readonly service: IntegrationsAdminService) {}

  @Get()
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Header('Cache-Control', 'public, max-age=300')
  @ApiOperation({ summary: '{ mapboxPublicToken } — Mapbox pk.* token for map tiles (null when unset).' })
  get() {
    return this.service.clientConfig();
  }
}
