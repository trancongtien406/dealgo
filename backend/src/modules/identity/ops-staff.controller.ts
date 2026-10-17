import { Controller, Get, Param, ParseUUIDPipe, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { OpsSessionGuard } from './access-auth.guard.js';
import { OpsUsersPageQueryDto } from './ops-users.dto.js';
import { OpsUsersService } from './ops-users.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/staff')
@UseGuards(OpsSessionGuard)
export class OpsStaffController {
  constructor(private readonly users: OpsUsersService) {}

  @Get()
  @ApiOperation({ summary: 'Ops paginated staff members (users with OPS role grant)' })
  list(@Query() query: OpsUsersPageQueryDto) {
    return this.users.listStaff(query.page, query.limit, {
      q: query.q,
      status: query.status,
      role: query.role,
      scope: query.scope,
    });
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Ops staff detail (safe fields; no credentials or session tokens)',
  })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.getStaff(id);
  }
}
