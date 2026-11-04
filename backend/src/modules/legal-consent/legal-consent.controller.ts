import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import type { Request } from 'express';
import { extractClientIp } from '../../platform/http/client-ip.decorator.js';
import { AccessAuthGuard, CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { PublishLegalVersionDto, SendLegalEmailDto } from './legal-consent.dto.js';
import { LegalConsentService } from './legal-consent.service.js';

/** pt5u: documents (with current versions) a driver/shop applicant must accept. */
@ApiTags('public')
@Controller('v1/public/legal-documents')
@UseGuards(ThrottlerGuard)
export class PublicLegalDocumentsController {
  constructor(private readonly legal: LegalConsentService) {}

  @Get('partner-application')
  @ApiOperation({ summary: 'Current versions of Quy chế sử dụng + privacy to accept when registering as driver/shop' })
  partnerApplication() {
    return this.legal.currentApplicationDocuments();
  }
}

@ApiTags('me')
@ApiBearerAuth()
@Controller('v1/me/legal-consents')
@UseGuards(AccessAuthGuard)
export class LegalConsentController {
  constructor(private readonly legal: LegalConsentService) {}

  @Get('pending')
  @ApiOperation({ summary: 'Legal document versions the user must accept before using the app' })
  pending(@CurrentActor() actor: RequestActor) {
    return this.legal.pending(actor.userId);
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Accept one version (audited with time, IP, user agent)' })
  accept(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string, @Req() req: Request) {
    return this.legal.accept(actor.userId, id, {
      ip: extractClientIp(req),
      userAgent: typeof req.headers['user-agent'] === 'string' ? req.headers['user-agent'] : null,
    });
  }
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/legal-versions')
@UseGuards(OpsPermissionGuard)
export class OpsLegalVersionsController {
  constructor(private readonly legal: LegalConsentService) {}

  @RequireOpsPermission('content.write')
  @Get()
  list() {
    return this.legal.listVersions();
  }

  @RequireOpsPermission('content.write')
  @Post()
  @ApiOperation({ summary: 'Require consent for the currently published version of terms/privacy' })
  publish(@CurrentActor() actor: RequestActor, @Body() body: PublishLegalVersionDto) {
    return this.legal.publish(body, actor.userId);
  }

  @RequireOpsPermission('content.write')
  @Get(':id/email-preview')
  preview(@Param('id', ParseUUIDPipe) id: string) {
    return this.legal.emailPreview(id);
  }

  @RequireOpsPermission('content.write')
  @Post(':id/email')
  @HttpCode(HttpStatus.ACCEPTED)
  @ApiOperation({ summary: 'Queue the "terms changed" email (confirmCount must equal the preview)' })
  send(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string, @Body() body: SendLegalEmailDto) {
    return this.legal.queueEmail(id, body.confirmCount, actor.userId);
  }
}
