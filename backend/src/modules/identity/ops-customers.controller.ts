import { Controller, Get, Param, ParseUUIDPipe, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { OpsSessionGuard } from './access-auth.guard.js';
import { OpsUsersPageQueryDto } from './ops-users.dto.js';
import { OpsUsersService } from './ops-users.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/customers')
@UseGuards(OpsSessionGuard)
export class OpsCustomersController {
  constructor(private readonly users: OpsUsersService) {}

  @Get()
  @ApiOperation({ summary: 'Ops paginated customers (users with CUSTOMER role grant)' })
  list(@Query() query: OpsUsersPageQueryDto) {
    return this.users.listCustomers(query.page, query.limit, {
      q: query.q,
      status: query.status,
      region: query.region,
      service: query.service,
    });
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Ops customer detail (safe fields; no credentials or session tokens)',
  })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.getCustomer(id);
  }

  @Get(':id/activities')
  @ApiOperation({
    summary: 'Ops customer activities by tab (rides, food orders, deliveries, payments, notes)',
  })
  getActivities(
    @Param('id') id: string,
    @Query('tab') tab?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.users.getCustomerActivities(id, {
      tab,
      page: page ? Number(page) : 1,
      limit: limit ? Number(limit) : 6,
    });
  }
}

