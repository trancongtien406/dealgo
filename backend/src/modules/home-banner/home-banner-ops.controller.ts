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
  CreateHomeBannerDto,
  PatchHomeBannerDto,
  ReorderHomeBannersDto,
  UploadHomeBannerImageDto,
} from './home-banner.dto.js';
import { HomeBannerService } from './home-banner.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/home-banners')
@UseGuards(OpsPermissionGuard)
export class HomeBannerOpsController {
  constructor(private readonly banners: HomeBannerService) {}

  @Get()
  @ApiOperation({ summary: 'All home banners with state (LIVE/SCHEDULED/EXPIRED/INACTIVE/NO_IMAGE) and impression/click stats' })
  list() {
    return this.banners.listOps();
  }

  @RequireOpsPermission('content.write')
  @Post()
  @ApiOperation({ summary: 'Create a home banner (inactive until an image is uploaded)' })
  create(@CurrentActor() actor: RequestActor, @Body() body: CreateHomeBannerDto) {
    return this.banners.create(body, actor.userId);
  }

  @RequireOpsPermission('content.write')
  @Post('reorder')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Set display order: ids first-to-last' })
  reorder(@CurrentActor() actor: RequestActor, @Body() body: ReorderHomeBannersDto) {
    return this.banners.reorder(body.ids, actor.userId);
  }

  @RequireOpsPermission('content.write')
  @Patch(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update a home banner; CTA must be an allowlisted in-app page or https' })
  patch(@CurrentActor() actor: RequestActor, @Param('id') id: string, @Body() body: PatchHomeBannerDto) {
    return this.banners.update(id, body, actor.userId);
  }

  @RequireOpsPermission('content.write')
  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete a home banner and its image' })
  remove(@CurrentActor() actor: RequestActor, @Param('id') id: string) {
    return this.banners.remove(id, actor.userId);
  }

  @RequireOpsPermission('content.write')
  @Post(':id/image')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Upload the banner image (JPEG/PNG/WebP, 2:1 recommended, e.g. 1200×600)' })
  uploadImage(
    @CurrentActor() actor: RequestActor,
    @Param('id') id: string,
    @Body() body: UploadHomeBannerImageDto,
  ) {
    return this.banners.uploadImage(id, body, actor.userId);
  }
}
