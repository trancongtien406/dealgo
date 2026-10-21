import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ListOpsAuditLogsQueryDto } from './ops-audit-logs.dto.js';
import { OpsAuditLogsService } from './ops-audit-logs.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/audit-logs')
@UseGuards(OpsPermissionGuard)
export class OpsAuditLogsController {
  constructor(private readonly auditLogsService: OpsAuditLogsService) {}

  @RequireOpsPermission('staff.read')
  @Get()
  @ApiOperation({
    summary: 'List immutable ops audit log events (CAP-OPS-05, settings, faqs, disputes, auth updates).',
  })
  list(@Query() query: ListOpsAuditLogsQueryDto) {
    return this.auditLogsService.list({
      q: query.q,
      entityType: query.entityType,
      result: query.result,
      page: query.page,
      limit: query.limit,
    });
  }
}
