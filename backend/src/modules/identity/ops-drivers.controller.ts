import { Controller, Get, Param, ParseUUIDPipe, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { OpsPermissionGuard } from './ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from './ops-rbac/ops-permission.decorator.js';
import { OpsUsersPageQueryDto } from './ops-users.dto.js';
import { OpsUsersService } from './ops-users.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/drivers')
@UseGuards(OpsPermissionGuard)
export class OpsDriversController {
  constructor(private readonly users: OpsUsersService) {}

  @RequireOpsPermission('drivers.read')
  @Get()
  @ApiOperation({
    summary: 'Ops paginated drivers (users with DRIVER role grant + presence summary)',
  })
  list(@Query() query: OpsUsersPageQueryDto) {
    return this.users.listDrivers(query.page, query.limit, {
      q: query.q,
      status: query.status,
      service: query.service,
      region: query.region,
      activity: query.activity,
      kyc: query.kyc,
    });
  }

  @RequireOpsPermission('drivers.read')
  @Get(':id')
  @ApiOperation({
    summary: 'Ops driver detail (safe fields + presence; no credentials or session tokens)',
  })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.getDriver(id);
  }
}
