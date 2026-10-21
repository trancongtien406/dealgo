import {
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
  CustomerSessionGuard,
  type RequestActor,
} from '../../identity/access-auth.guard.js';
import { ListInboxQueryDto } from './inbox.dto.js';
import { InboxService } from './inbox.service.js';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('v1/me/notifications')
@UseGuards(CustomerSessionGuard)
export class InboxController {
  constructor(private readonly inbox: InboxService) {}

  @Get()
  @ApiOperation({ summary: 'In-app notification inbox for the signed-in app user (newest first)' })
  list(@CurrentActor() actor: RequestActor, @Query() query: ListInboxQueryDto) {
    return this.inbox.list(actor.userId, query);
  }

  @Post('read-all')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark every unread notification as read' })
  markAllRead(@CurrentActor() actor: RequestActor) {
    return this.inbox.markAllRead(actor.userId);
  }

  @Post(':id/read')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark one notification as read (owner only; others get 404)' })
  markRead(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.inbox.markRead(actor.userId, id);
  }
}
