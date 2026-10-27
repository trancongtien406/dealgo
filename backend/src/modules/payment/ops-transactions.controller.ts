import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { OpsTransactionsService } from './ops-transactions.service.js';
import { OpsDateRangeQueryDto, opsDateWindow } from '../operations/ops-date-window.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

export class OpsTransactionPageQueryDto extends OpsDateRangeQueryDto {
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

  @IsOptional()
  @IsString()
  service?: string;

  @IsOptional()
  @IsString()
  payment?: string;
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/transactions')
@UseGuards(OpsPermissionGuard)
export class OpsTransactionsController {
  constructor(private readonly transactions: OpsTransactionsService) {}

  @RequireOpsPermission('transactions.read')
  @Get()
  @ApiOperation({
    summary: 'Ops paginated transactions with server-side filters (q, status, service, payment, from/to Vietnam business days on payment intent createdAt)',
  })
  list(@Query() query: OpsTransactionPageQueryDto) {
    return this.transactions.list(query.page, query.limit, {
      q: query.q,
      status: query.status,
      service: query.service,
      payment: query.payment,
      window: opsDateWindow(query),
    });
  }
}
