import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { PARTNER_APPLICATION_ROLES } from './partner.constants.js';
import { SubmitPartnerApplicationDto } from './partner.dto.js';
import { partnerError } from './partner.error.js';
import type { PartnerRoleName } from './partner.repository.js';
import { PartnerService } from './partner.service.js';

@ApiTags('identity')
@ApiBearerAuth()
@Controller('v1/me/partner-applications')
@UseGuards(CustomerSessionGuard)
export class MePartnerApplicationsController {
  constructor(private readonly partners: PartnerService) {}

  @Get()
  @ApiOperation({ summary: 'List my KYC/KYB partner applications' })
  listMine(@CurrentActor() actor: RequestActor) {
    return this.partners.listMine(actor.userId);
  }

  @Get('requirements/:role')
  @ApiOperation({
    summary:
      'DEC-PROD-048: whether KYC/KYB documents are required for a role and which kinds',
  })
  requirements(@Param('role') role: string, @Query('vehicleClassCode') vehicleClassCode?: string) {
    return this.partners.requirements(parseRole(role), vehicleClassCode);
  }

  @Get(':role')
  @ApiOperation({ summary: 'Get my partner application for a role' })
  getMine(@CurrentActor() actor: RequestActor, @Param('role') role: string) {
    return this.partners.getMine(actor.userId, parseRole(role));
  }

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Submit KYC (DRIVER) or KYB (MERCHANT) application' })
  submit(@CurrentActor() actor: RequestActor, @Body() body: SubmitPartnerApplicationDto) {
    return this.partners.submit(actor.userId, body);
  }
}

function parseRole(role: string): PartnerRoleName {
  const normalized = role.trim().toUpperCase();
  if ((PARTNER_APPLICATION_ROLES as readonly string[]).includes(normalized)) {
    return normalized as PartnerRoleName;
  }
  throw partnerError(400, 'VALIDATION_ERROR', 'role must be DRIVER or MERCHANT');
}
