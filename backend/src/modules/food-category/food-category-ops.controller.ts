import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import {
  CreateFoodCategoryDto,
  PatchFoodCategoryDto,
  ReorderFoodCategoriesDto,
  UploadFoodCategoryImageDto,
} from './food-category.dto.js';
import { FoodCategoryService } from './food-category.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/food-categories')
@UseGuards(OpsPermissionGuard)
export class FoodCategoryOpsController {
  constructor(private readonly categories: FoodCategoryService) {}

  @Get()
  @ApiOperation({ summary: 'All store categories in display order, with store counts' })
  list() {
    return this.categories.listOps();
  }

  @RequireOpsPermission('catalog.write')
  @Post()
  @ApiOperation({ summary: 'Create a store category; code is generated from nameVi and never changes' })
  create(@CurrentActor() actor: RequestActor, @Body() body: CreateFoodCategoryDto) {
    return this.categories.create(body, actor.userId);
  }

  @RequireOpsPermission('catalog.write')
  @Post('reorder')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Set display order: codes first-to-last' })
  reorder(@CurrentActor() actor: RequestActor, @Body() body: ReorderFoodCategoriesDto) {
    return this.categories.reorder(body.codes, actor.userId);
  }

  @RequireOpsPermission('catalog.write')
  @Patch(':code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Rename, change icon/colour, turn on/off or remove the image' })
  patch(@CurrentActor() actor: RequestActor, @Param('code') code: string, @Body() body: PatchFoodCategoryDto) {
    return this.categories.update(code, body, actor.userId);
  }

  @RequireOpsPermission('catalog.write')
  @Delete(':code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete a category no store uses (409 FOOD_CATEGORY_IN_USE otherwise)' })
  remove(@CurrentActor() actor: RequestActor, @Param('code') code: string) {
    return this.categories.remove(code, actor.userId);
  }

  @RequireOpsPermission('catalog.write')
  @Post(':code/image')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Upload the tile image (JPEG/PNG/WebP, square, ≤ 1 MB)' })
  uploadImage(
    @CurrentActor() actor: RequestActor,
    @Param('code') code: string,
    @Body() body: UploadFoodCategoryImageDto,
  ) {
    return this.categories.uploadImage(code, body, actor.userId);
  }
}
