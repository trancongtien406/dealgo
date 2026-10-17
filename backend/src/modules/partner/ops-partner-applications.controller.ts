import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
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
import {
  OpsPartnerApplicationQueryDto,
  RejectPartnerApplicationDto,
} from './partner.dto.js';
import { PartnerService } from './partner.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/partner-applications')
@UseGuards(OpsSessionGuard)
export class OpsPartnerApplicationsController {
  constructor(private readonly partners: PartnerService) {}

  @Get()
  @ApiOperation({ summary: 'List partner applications (default status=SUBMITTED)' })
  list(@Query() query: OpsPartnerApplicationQueryDto) {
    return this.partners.listForOps(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get partner application by ID for ops' })
  getById(@Param('id', ParseUUIDPipe) id: string) {
    return this.partners.getForOps(id);
  }

  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve submitted KYC/KYB; sets RoleGrant ACTIVE' })
  approve(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.partners.approve(id, actor.userId);
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Reject submitted KYC/KYB with reason; sets RoleGrant SUSPENDED',
  })
  reject(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: RejectPartnerApplicationDto,
  ) {
    return this.partners.reject(id, actor.userId, body.reason);
  }
}
