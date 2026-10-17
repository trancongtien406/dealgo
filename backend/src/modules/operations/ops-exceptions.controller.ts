import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { OpsSessionGuard } from '../identity/access-auth.guard.js';
import { OpsExceptionsService } from './ops-exceptions.service.js';

class OpsExceptionPageQueryDto {
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
@Controller('v1/ops/exceptions')
@UseGuards(OpsSessionGuard)
export class OpsExceptionsController {
  constructor(private readonly exceptions: OpsExceptionsService) {}

  @Get()
  @ApiOperation({
    summary:
      'Ops exception queue: stuck mid-lifecycle rides/food and recent FAILED/CANCELLED/EXPIRED',
  })
  list(@Query() query: OpsExceptionPageQueryDto) {
    return this.exceptions.list(query.page, query.limit, undefined, {
      q: query.q,
      status: query.status,
    });
  }
}
