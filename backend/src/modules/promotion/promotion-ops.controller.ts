import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CreatePromotionBodyDto,
  OpsPromotionQueryDto,
  UpdatePromotionStatusDto,
} from './promotion.dto.js';
import { PromotionService } from './promotion.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/promotions')
@UseGuards(OpsPermissionGuard)
export class PromotionOpsController {
  constructor(private readonly promotions: PromotionService) {}

  @Get()
  @ApiOperation({ summary: 'Ops list promotions with filters, pagination and KPIs' })
  list(@Query() query: OpsPromotionQueryDto) {
    return this.promotions.listPromotions(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Ops get promotion campaign detail' })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.promotions.getById(id);
  }

  @RequireOpsPermission('promotions.write')
  @Post()
  @ApiOperation({ summary: 'Ops create a new promotion voucher campaign' })
  create(@Body() body: CreatePromotionBodyDto) {
    return this.promotions.create(body);
  }

  @RequireOpsPermission('promotions.write')
  @Patch(':id/status')
  @ApiOperation({ summary: 'Ops update promotion status (active, paused, cancelled)' })
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: UpdatePromotionStatusDto,
  ) {
    return this.promotions.updateStatus(id, body.status);
  }
}
