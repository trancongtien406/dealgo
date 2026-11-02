import { Body, Controller, Get, Headers, HttpCode, HttpStatus, Patch, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { parseAppBuild, parseAppPlatform } from '../../platform/settings/index.js';
import { CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { PatchAppVersionPolicyDto } from './app-version.dto.js';
import { AppVersionService } from './app-version.service.js';

@ApiTags('public')
@Controller('v1/app')
@UseGuards(ThrottlerGuard)
export class AppVersionController {
  constructor(private readonly versions: AppVersionService) {}

  @Get('version-policy')
  @ApiOperation({
    summary: 'Update policy for ?platform=ios|android&build=N (or X-App-Platform / X-App-Build); verdict NONE|OPTIONAL|REQUIRED',
  })
  get(
    @Query('platform') platform?: string,
    @Query('build') build?: string,
    @Headers('x-app-platform') headerPlatform?: string,
    @Headers('x-app-build') headerBuild?: string,
  ) {
    return this.versions.publicView(
      parseAppPlatform(platform ?? headerPlatform),
      parseAppBuild(build ?? headerBuild),
    );
  }
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/app-version-policy')
@UseGuards(OpsPermissionGuard)
export class OpsAppVersionController {
  constructor(private readonly versions: AppVersionService) {}

  @RequireOpsPermission('settings.write')
  @Get()
  get() {
    return this.versions.policy();
  }

  @RequireOpsPermission('settings.write')
  @Patch()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Replace the app update policy { policy, reason }; audited (SETTINGS_UPDATE)' })
  patch(@CurrentActor() actor: RequestActor, @Body() body: PatchAppVersionPolicyDto) {
    return this.versions.update(body.policy, body.reason, actor.userId);
  }
}
