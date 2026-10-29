import {
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import {
  CurrentActor,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { PatchSiteConfigDto } from './site-config.dto.js';
import { SiteConfigService } from './site-config.service.js';

@ApiTags('public')
@Controller('v1/public/site-config')
@UseGuards(ThrottlerGuard)
export class PublicSiteConfigController {
  constructor(private readonly siteConfig: SiteConfigService) {}

  @Get()
  @Header('Cache-Control', 'public, max-age=60, stale-while-revalidate=300')
  @ApiOperation({
    summary:
      'Website store links, socials, contact, coming-soon cities (empty fields omitted)',
  })
  get() {
    return this.siteConfig.get();
  }
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/site-config')
@UseGuards(OpsPermissionGuard)
export class OpsSiteConfigController {
  constructor(private readonly siteConfig: SiteConfigService) {}

  @RequireOpsPermission('settings.write')
  @Get()
  get() {
    return this.siteConfig.get();
  }

  @RequireOpsPermission('settings.write')
  @Patch()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Replace website links { config, reason }; https + allowed hosts; audited',
  })
  patch(@CurrentActor() actor: RequestActor, @Body() body: PatchSiteConfigDto) {
    return this.siteConfig.update(body.config, body.reason, actor.userId);
  }
}
