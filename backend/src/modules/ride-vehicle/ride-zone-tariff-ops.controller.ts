import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { PutRideZoneTariffDto } from './ride-vehicle-class.dto.js';
import { RideZoneTariffService } from './ride-zone-tariff.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/ride-zone-tariffs')
@UseGuards(OpsPermissionGuard)
export class RideZoneTariffOpsController {
  constructor(private readonly tariffs: RideZoneTariffService) {}

  @Get()
  @ApiOperation({
    summary:
      'Regions x vehicle classes with per-zone perKm/minFare overrides. Missing override = global class tariff. Existing rides keep their locked snapshot.',
  })
  list() {
    return this.tariffs.listMatrix();
  }

  @RequireOpsPermission('settings.write')
  @Put(':regionCode/:vehicleClassCode')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Create or update one zone override (audit-logged, bumps version).' })
  put(
    @CurrentActor() actor: RequestActor,
    @Param('regionCode') regionCode: string,
    @Param('vehicleClassCode') vehicleClassCode: string,
    @Body() body: PutRideZoneTariffDto,
  ) {
    return this.tariffs.upsert(regionCode, vehicleClassCode, body, actor.userId);
  }

  @RequireOpsPermission('settings.write')
  @Delete(':regionCode/:vehicleClassCode')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove one zone override so the zone falls back to the global class tariff (audit-logged).' })
  remove(
    @CurrentActor() actor: RequestActor,
    @Param('regionCode') regionCode: string,
    @Param('vehicleClassCode') vehicleClassCode: string,
    @Query('reason') reason?: string,
  ) {
    return this.tariffs.remove(regionCode, vehicleClassCode, actor.userId, reason);
  }
}
