import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import {
  CurrentActor,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import {
  CreateOpsZoneDto,
  ListOpsZonesQueryDto,
  PatchOpsZoneDto,
} from './service-zones.dto.js';
import { OpsZonesService } from './service-zones.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

class OpsZonesRulesQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @IsOptional()
  @IsString()
  q?: string;
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/zones')
@UseGuards(OpsPermissionGuard)
export class OpsZonesController {
  constructor(private readonly zones: OpsZonesService) {}

  @Get()
  @ApiOperation({
    summary:
      'List service zones with open demand counts by serviceRegionCode. Default status=ACTIVE; use status=ALL for the management table.',
  })
  listZones(@Query() query: ListOpsZonesQueryDto) {
    return this.zones.listZones({ status: query.status });
  }

  @RequireOpsPermission('zones.write')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary:
      'Create a service zone { code, label, center, bbox, status?, reason }. Writes OpsAuditLog SERVICE_REGION_UPDATE. Zones are never deleted — set status PLANNED to disable.',
  })
  createZone(@CurrentActor() actor: RequestActor, @Body() body: CreateOpsZoneDto) {
    return this.zones.createZone(body, actor.userId);
  }

  @RequireOpsPermission('zones.write')
  @Patch(':code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Patch a service zone (label/center/bbox/status) with a required reason. Cannot deactivate the last ACTIVE zone.',
  })
  patchZone(
    @CurrentActor() actor: RequestActor,
    @Param('code') code: string,
    @Body() body: PatchOpsZoneDto,
  ) {
    return this.zones.patchZone(code, body, actor.userId);
  }

  @Get('rules')
  @ApiOperation({
    summary: 'List pricing rules derived from PlatformSetting fare / radius knobs',
  })
  listRules(@Query() query: OpsZonesRulesQueryDto) {
    return this.zones.listRules(query);
  }
}

export {
  OpsZonesController as ServiceZonesController,
  OpsZonesController as ZoneController,
};

