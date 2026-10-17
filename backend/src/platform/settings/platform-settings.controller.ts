import { Body, Controller, Get, HttpCode, HttpStatus, Param, Patch, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  OpsSessionGuard,
  type RequestActor,
} from '../../modules/identity/access-auth.guard.js';
import { PatchPlatformSettingDto, QueryPlatformSettingsDto } from './platform-settings.dto.js';
import { PlatformSettingsService } from './platform-settings.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/platform-settings')
@UseGuards(OpsSessionGuard)
export class OpsPlatformSettingsController {
  constructor(private readonly settings: PlatformSettingsService) {}

  @Get()
  @ApiOperation({
    summary:
      'List Admin PlatformSettings with optional search and category filters. Lazy-seeds from env bootstrap; DB overrides env.',
  })
  list(@Query() query: QueryPlatformSettingsDto) {
    return this.settings.list(query);
  }

  @Patch(':key')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Patch a platform setting by key { value, reason }. Validates type/range; writes OpsAuditLog SETTINGS_UPDATE.',
  })
  patch(
    @CurrentActor() actor: RequestActor,
    @Param('key') key: string,
    @Body() body: PatchPlatformSettingDto,
  ) {
    return this.settings.patch(key, body.value, body.reason, actor.userId);
  }
}
