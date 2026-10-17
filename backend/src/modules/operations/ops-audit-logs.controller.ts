import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { OpsSessionGuard } from '../identity/access-auth.guard.js';
import { ListOpsAuditLogsQueryDto } from './ops-audit-logs.dto.js';
import { OpsAuditLogsService } from './ops-audit-logs.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/audit-logs')
@UseGuards(OpsSessionGuard)
export class OpsAuditLogsController {
  constructor(private readonly auditLogsService: OpsAuditLogsService) {}

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
