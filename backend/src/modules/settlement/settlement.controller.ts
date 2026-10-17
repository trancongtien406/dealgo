import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { OpsSessionGuard } from '../identity/access-auth.guard.js';
import { SettlementService } from './settlement.service.js';

export class SettlementPageQueryDto {
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
@UseGuards(OpsSessionGuard)
export class SettlementController {
  constructor(private readonly settlements: SettlementService) {}

  @Get()
  @ApiOperation({
    summary:
      'Sandbox settlement stub: COD ledger journals grouped by UTC day (read-only; no payout)',
  })
  list(@Query() query: SettlementPageQueryDto) {
    return this.settlements.list(query.page, query.limit);
  }
}

export const OpsSettlementsController = SettlementController;
export type OpsSettlementsController = SettlementController;
