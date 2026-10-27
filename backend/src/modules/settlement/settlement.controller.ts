import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { SettlementService } from './settlement.service.js';
import { OpsDateRangeQueryDto, opsDateWindow } from '../operations/ops-date-window.js';

export class SettlementPageQueryDto extends OpsDateRangeQueryDto {
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
}

export const OpsSettlementPageQueryDto = SettlementPageQueryDto;
export type OpsSettlementPageQueryDto = SettlementPageQueryDto;

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/settlements')
@UseGuards(OpsPermissionGuard)
export class SettlementController {
  constructor(private readonly settlements: SettlementService) {}

  @Get()
  @RequireOpsPermission('settlements.read')
  @ApiOperation({
    summary:
      'COD ledger journals grouped by Vietnam business day (Asia/Ho_Chi_Minh, YYYY-MM-DD), newest first; optional from/to (inclusive business days). Read-only; no payout.',
  })
  list(@Query() query: SettlementPageQueryDto) {
    opsDateWindow(query);
    return this.settlements.list(query.page, query.limit, { from: query.from, to: query.to });
  }
}

export const OpsSettlementsController = SettlementController;
export type OpsSettlementsController = SettlementController;
