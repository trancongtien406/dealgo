import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { RoleGrantsService } from './role-grants.service.js';
import { OpsPermissionGuard } from './ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from './ops-rbac/ops-permission.decorator.js';

@ApiTags('identity')
@ApiBearerAuth()
@Controller('v1/ops/role-grants')
@UseGuards(OpsPermissionGuard)
export class OpsRoleGrantsController {
  constructor(private readonly roleGrants: RoleGrantsService) {}

  @Get()
  @ApiOperation({
    summary:
      'List role grants for staff review. Default ?status=PENDING; also ACTIVE|SUSPENDED.',
  })
  list(
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.roleGrants.listForOps(
      status,
      page ? Number(page) : 1,
      limit ? Number(limit) : 20,
    );
  }

  @RequireOpsPermission('staff.write')
  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve a pending role grant' })
  approve(@Param('id', ParseUUIDPipe) id: string) {
    return this.roleGrants.approve(id);
  }

  @RequireOpsPermission('staff.write')
  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject a pending role grant' })
  reject(@Param('id', ParseUUIDPipe) id: string) {
    return this.roleGrants.reject(id);
  }
}
