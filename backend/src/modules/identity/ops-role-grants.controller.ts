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
import { OpsSessionGuard } from './access-auth.guard.js';
import { RoleGrantsService } from './role-grants.service.js';

@ApiTags('identity')
@ApiBearerAuth()
@Controller('v1/ops/role-grants')
@UseGuards(OpsSessionGuard)
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

  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve a pending role grant' })
  approve(@Param('id', ParseUUIDPipe) id: string) {
    return this.roleGrants.approve(id);
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject a pending role grant' })
  reject(@Param('id', ParseUUIDPipe) id: string) {
    return this.roleGrants.reject(id);
  }
}
