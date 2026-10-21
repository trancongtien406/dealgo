import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { DriverHistoryQueryDto } from './driver-history.dto.js';
import { DriverHistoryService } from './driver-history.service.js';

@ApiTags('driver')
@ApiBearerAuth()
@Controller('v1/driver/history')
@UseGuards(CustomerSessionGuard)
export class DriverHistoryController {
  constructor(private readonly history: DriverHistoryService) {}

  @Get()
  @ApiOperation({ summary: 'Driver finished jobs (rides + food), newest first, cursor paged' })
  list(@CurrentActor() actor: RequestActor, @Query() query: DriverHistoryQueryDto) {
    return this.history.list(actor.userId, query);
  }

  @Get('summary')
  @ApiOperation({ summary: 'Driver earnings for today and the last 7 days (UTC+7) plus rating' })
  summary(@CurrentActor() actor: RequestActor) {
    return this.history.summary(actor.userId);
  }
}
