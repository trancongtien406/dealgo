import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CatalogModerationQueryDto } from './catalog.dto.js';
import { CatalogService } from './catalog.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/catalog')
@UseGuards(OpsPermissionGuard)
export class CatalogOpsController {
  constructor(private readonly catalog: CatalogService) {}

  @Get('moderation')
  @ApiOperation({
    summary:
      'Ops catalog moderation queue with server filters & pagination; optional from/to (inclusive Vietnam business days on item submission time)',
  })
  list(@Query() query: CatalogModerationQueryDto) {
    return this.catalog.listModeration(query);
  }

  @RequireOpsPermission('catalog.write')
  @Post('items/:id/approve')
  @ApiOperation({ summary: 'Approve catalog item' })
  approve(@Param('id') id: string) {
    return this.catalog.approveItem(id);
  }

  @RequireOpsPermission('catalog.write')
  @Post('items/:id/reject')
  @ApiOperation({ summary: 'Reject catalog item' })
  reject(@Param('id') id: string) {
    return this.catalog.rejectItem(id);
  }
}

export { CatalogOpsController as OpsCatalogController };
