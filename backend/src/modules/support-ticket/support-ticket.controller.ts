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
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { ThrottlerGuard } from '@nestjs/throttler';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import {
  CreatePublicSupportTicketDto,
  CreateSupportTicketDto,
  ListMySupportTicketsQueryDto,
  ListOpsSupportTicketsQueryDto,
  PatchOpsSupportTicketDto,
  SupportAttachmentParamsDto,
  SupportMessageDto,
} from './support-ticket.dto.js';
import { SupportTicketService } from './support-ticket.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('support')
@ApiBearerAuth()
@Controller('v1/support/tickets')
@UseGuards(CustomerSessionGuard)
export class SupportTicketController {
  constructor(private readonly tickets: SupportTicketService) {}

  @Get()
  @ApiOperation({ summary: 'My support tickets, latest activity first. ?state=ACTIVE|DONE' })
  list(@CurrentActor() actor: RequestActor, @Query() query: ListMySupportTicketsQueryDto) {
    return this.tickets.listMine(actor.userId, query);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary:
      'Open a support ticket (optionally about one of my rides/orders). Open tickets per user are capped by SUPPORT_TICKET_MAX_OPEN_PER_USER.',
  })
  create(@CurrentActor() actor: RequestActor, @Body() body: CreateSupportTicketDto) {
    return this.tickets.create(actor.userId, body);
  }

  @Get(':id')
  @ApiOperation({ summary: 'One of my tickets with its message thread' })
  get(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.tickets.getMine(actor.userId, id);
  }

  @Post(':id/messages')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Add a message to my ticket (reopens a RESOLVED ticket; CLOSED → 409)' })
  message(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: SupportMessageDto,
  ) {
    return this.tickets.addMine(actor.userId, id, body.body, body.attachments ?? []);
  }

  @Get(':id/messages/:messageId/attachments/:index')
  @SkipResponseEnvelope()
  @ApiOperation({ summary: 'Download an attachment from one of my tickets' })
  async attachment(
    @CurrentActor() actor: RequestActor,
    @Param() params: SupportAttachmentParamsDto,
  ): Promise<StreamableFile> {
    return streamable(
      await this.tickets.readMineAttachment(actor.userId, params.id, params.messageId, params.index),
    );
  }
}

@ApiTags('public')
@Controller('v1/public/support/tickets')
@UseGuards(ThrottlerGuard)
export class PublicSupportTicketController {
  constructor(private readonly tickets: SupportTicketService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary:
      'Website support form. Returns only the ticket code. Per-contact daily cap SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY (429).',
  })
  create(@Body() body: CreatePublicSupportTicketDto) {
    return this.tickets.createPublic(body);
  }
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/support-tickets')
@UseGuards(OpsPermissionGuard)
export class OpsSupportTicketController {
  constructor(private readonly tickets: SupportTicketService) {}

  @Get()
  @ApiOperation({ summary: 'Support tickets for Ops. ?status=&category=&channel=&q=&page=&limit=' })
  list(@Query() query: ListOpsSupportTicketsQueryDto) {
    return this.tickets.listForOps(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Ticket detail with requester and full thread' })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.tickets.getForOps(id);
  }

  @RequireOpsPermission('tickets.write')
  @Patch(':id')
  @ApiOperation({ summary: 'Change status and/or priority; writes OpsAuditLog SUPPORT_TICKET_UPDATE' })
  patch(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: PatchOpsSupportTicketDto,
  ) {
    return this.tickets.patchForOps(actor.userId, id, body);
  }

  @RequireOpsPermission('tickets.write')
  @Post(':id/replies')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Reply as DealGo support (OPEN → IN_PROGRESS; CLOSED → 409). Notifies an app requester in the inbox.',
  })
  reply(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: SupportMessageDto,
  ) {
    return this.tickets.replyForOps(actor.userId, id, body.body, body.attachments ?? []);
  }

  @Get(':id/messages/:messageId/attachments/:index')
  @SkipResponseEnvelope()
  @ApiOperation({ summary: 'Download a ticket attachment (Ops)' })
  async attachment(@Param() params: SupportAttachmentParamsDto): Promise<StreamableFile> {
    return streamable(
      await this.tickets.readOpsAttachment(params.id, params.messageId, params.index),
    );
  }
}

function streamable(file: { body: Buffer; contentType: string; filename: string }): StreamableFile {
  return new StreamableFile(file.body, {
    type: file.contentType,
    length: file.body.byteLength,
    disposition: `inline; filename="${file.filename}"`,
  });
}
