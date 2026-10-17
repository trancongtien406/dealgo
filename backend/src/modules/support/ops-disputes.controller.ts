import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  OpsSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { ResolveDisputeDto } from './ops-disputes.dto.js';
import { OpsDisputesService } from './ops-disputes.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/disputes')
@UseGuards(OpsSessionGuard)
export class OpsDisputesController {
  constructor(private readonly disputesService: OpsDisputesService) {}

  @Get()
  @ApiOperation({
    summary: 'List disputes with filters (search, status, priority, pagination).',
  })
  list(
    @Query('q') q?: string,
    @Query('status') status?: string,
    @Query('priority') priority?: string,
    @Query('type') type?: string,
    @Query('party') party?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.disputesService.list({ q, status, priority, type, party, page, limit });
  }

  @Get(':code')
  @ApiOperation({
    summary:
      'Get detailed dispute case by code. Returns 404 when unknown (no synthesized demo cases).',
  })
  get(@Param('code') code: string) {
    return this.disputesService.getByCode(code);
  }

  @Post(':code/resolve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Resolve dispute. Money remedies record RefundRequest + ledger journal. Status remedies update case + OpsAuditLog.',
  })
  resolve(
    @Param('code') code: string,
    @CurrentActor() actor: RequestActor,
    @Body() body: ResolveDisputeDto,
  ) {
    return this.disputesService.resolve(code, body, actor.userId);
  }
}
