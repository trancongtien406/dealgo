import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { IsOptional, Matches } from 'class-validator';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsReportsService } from './ops-reports.service.js';

export class OpsReportQueryDto {
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  from?: string;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  to?: string;
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/reports')
@UseGuards(OpsPermissionGuard)
export class OpsReportsController {
  constructor(private readonly reports: OpsReportsService) {}

  @Get()
  @RequireOpsPermission('reports.read')
  @ApiQuery({ name: 'from', required: false, description: 'First Vietnam business day (YYYY-MM-DD); default today' })
  @ApiQuery({ name: 'to', required: false, description: 'Last Vietnam business day, inclusive (YYYY-MM-DD); default = from' })
  @ApiOperation({
    summary:
      'Period report per Vietnam business day (Asia/Ho_Chi_Minh): completed/cancelled rides and food orders, gross booking value (revenueVnd) and platform commission. Max 92 days.',
  })
  get(@Query() query: OpsReportQueryDto) {
    return this.reports.report(query);
  }
}
