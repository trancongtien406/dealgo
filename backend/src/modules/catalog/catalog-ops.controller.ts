import { Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { OpsSessionGuard } from '../identity/access-auth.guard.js';
import {
  CatalogCategoriesQueryDto,
  CatalogModerationQueryDto,
} from './catalog.dto.js';
import { CatalogService } from './catalog.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/catalog')
@UseGuards(OpsSessionGuard)
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

  @Get('moderation')
  @ApiOperation({
    summary: 'Ops catalog moderation queue with server filters & pagination',
  })
  list(@Query() query: CatalogModerationQueryDto) {
    return this.catalog.listModeration(query);
  }

  @Post('items/:id/approve')
  @ApiOperation({ summary: 'Approve catalog item' })
  approve(@Param('id') id: string) {
    return this.catalog.approveItem(id);
  }

  @Post('items/:id/reject')
  @ApiOperation({ summary: 'Reject catalog item' })
  reject(@Param('id') id: string) {
    return this.catalog.rejectItem(id);
  }
}

export { CatalogOpsController as OpsCatalogController };
