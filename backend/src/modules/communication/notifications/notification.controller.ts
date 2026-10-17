import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  OpsSessionGuard,
  type RequestActor,
} from '../../identity/access-auth.guard.js';
import {
  CampaignReasonDto,
  CreateCampaignDto,
  CreateCmsDto,
  ListCampaignsQueryDto,
  ListCmsQueryDto,
  OptionalReasonDto,
  PatchCmsDto,
  UpdateCampaignDto,
} from './notification.dto.js';
import { NotificationService } from './notification.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/notifications')
@UseGuards(OpsSessionGuard)
export class NotificationController {
  constructor(private readonly notifications: NotificationService) {}

  // ---- Campaigns ----

  @Get()
  @ApiOperation({
    summary:
      'List notification campaigns. Server-side filter ?tab=ALL|RUNNING|SENT|PENDING|DRAFT &channel= &audience= &q=; returns per-tab counts.',
  })
  list(@Query() query: ListCampaignsQueryDto) {
    return this.notifications.listCampaigns(query);
  }

  // Declared before ':code' so the literal segment is never captured as a campaign code.
  @Get('cms')
  @ApiOperation({ summary: 'List CMS content (articles / banners / policies). ?kind= &status= &q=' })
  listCms(@Query() query: ListCmsQueryDto) {
    return this.notifications.listCms(query);
  }

  @Post('cms')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create CMS content; writes OpsAuditLog CMS_UPDATE.' })
  createCms(@CurrentActor() actor: RequestActor, @Body() body: CreateCmsDto) {
    return this.notifications.createCms(Object.assign({}, body, { actorUserId: actor.userId }));
  }

  @Get('cms/:id')
  @ApiOperation({ summary: 'Get one CMS content item.' })
  getCms(@Param('id', ParseUUIDPipe) id: string) {
    return this.notifications.getCms(id);
  }

  @Patch('cms/:id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Edit CMS content or move it through DRAFT → IN_REVIEW → PUBLISHED; writes OpsAuditLog CMS_UPDATE.',
  })
  patchCms(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: PatchCmsDto,
  ) {
    return this.notifications.patchCms(Object.assign({}, body, { id, actorUserId: actor.userId }));
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary:
      'Create a campaign as DRAFT (code TB-YYMMDD-NNN). OTP / verification-code content is rejected.',
  })
  create(@CurrentActor() actor: RequestActor, @Body() body: CreateCampaignDto) {
    return this.notifications.createCampaign(Object.assign({}, body, { actorUserId: actor.userId }));
  }

  @Get(':code')
  @ApiOperation({ summary: 'Get one campaign by code.' })
  get(@Param('code') code: string) {
    return this.notifications.getCampaign(code);
  }

  @Patch(':code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Edit a campaign. Only DRAFT campaigns are editable (409 otherwise).' })
  update(
    @CurrentActor() actor: RequestActor,
    @Param('code') code: string,
    @Body() body: UpdateCampaignDto,
  ) {
    return this.notifications.updateCampaign(Object.assign({}, body, { code, actorUserId: actor.userId }));
  }

  @Post(':code/submit')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'DRAFT → PENDING_APPROVAL.' })
  submit(
    @CurrentActor() actor: RequestActor,
    @Param('code') code: string,
    @Body() body: OptionalReasonDto,
  ) {
    return this.notifications.submitCampaign(code, actor.userId, body.reason);
  }

  @Post(':code/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'PENDING_APPROVAL → RUNNING (scheduled / automatic) or SENDING (due now). PUSH channel enqueues outbox fan-out to registered device tokens.',
  })
  approve(
    @CurrentActor() actor: RequestActor,
    @Param('code') code: string,
    @Body() body: CampaignReasonDto,
  ) {
    return this.notifications.approveCampaign(code, actor.userId, body.reason);
  }

  @Post(':code/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'PENDING_APPROVAL → DRAFT with a reviewer note (rejectionReason).' })
  reject(
    @CurrentActor() actor: RequestActor,
    @Param('code') code: string,
    @Body() body: CampaignReasonDto,
  ) {
    return this.notifications.rejectCampaign(code, actor.userId, body.reason);
  }

  @Post(':code/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'DRAFT | PENDING_APPROVAL | RUNNING → CANCELLED.' })
  cancel(
    @CurrentActor() actor: RequestActor,
    @Param('code') code: string,
    @Body() body: CampaignReasonDto,
  ) {
    return this.notifications.cancelCampaign(code, actor.userId, body.reason);
  }
}

export const OpsNotificationsController = NotificationController;
export type OpsNotificationsController = NotificationController;

