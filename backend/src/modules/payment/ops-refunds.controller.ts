import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsRefundsService } from './ops-refunds.service.js';

class OpsRefundsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsString()
  status?: string;
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/refunds')
@UseGuards(OpsPermissionGuard)
export class OpsRefundsController {
  constructor(private readonly refunds: OpsRefundsService) {}

  @Get()
  @RequireOpsPermission('refunds.read')
  @ApiOperation({
    summary:
      'List refund-related ops cases derived from disputes (open refund requests and PARTIAL/FULL refund resolutions)',
  })
  list(@Query() query: OpsRefundsQueryDto) {
    return this.refunds.list(query);
  }
}
