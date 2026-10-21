import { Body, Controller, Get, HttpCode, HttpStatus, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CatalogCategoriesQueryDto,
  CatalogModerationQueryDto,
  RenameCatalogCategoryDto,
} from './catalog.dto.js';
import { CatalogService } from './catalog.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/catalog')
@UseGuards(OpsPermissionGuard)
export class CatalogOpsController {
  constructor(private readonly catalog: CatalogService) {}

  @Get('categories')
  @ApiOperation({
    summary: 'List food store categories aggregated from FoodStore.category',
  })
  listCategories(@Query() query: CatalogCategoriesQueryDto) {
    return this.catalog.listCategories(query);
  }

  @Get('categories/:code')
  @ApiOperation({ summary: 'Get one aggregated store category by slug code' })
  getCategory(@Param('code') code: string) {
    return this.catalog.getCategory(code);
  }

  @RequireOpsPermission('catalog.write')
  @Patch('categories/:code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'A030 rename a store-type category (updates FoodStore.category for every matching store)',
  })
  renameCategory(@Param('code') code: string, @Body() dto: RenameCatalogCategoryDto) {
    return this.catalog.renameCategory(code, dto.name);
  }

  @Get('moderation')
  @ApiOperation({
    summary: 'Ops catalog moderation queue with server filters & pagination',
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
