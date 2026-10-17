import { Body, Controller, Get, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AccessAuthGuard, CurrentActor, type RequestActor } from './access-auth.guard.js';
import { CurrentUserService } from './current-user.service.js';
import { DriverPresenceService } from './driver-presence.service.js';
import { UpsertPresenceDto } from './presence.dto.js';

@ApiTags('identity')
@ApiBearerAuth()
@Controller('v1/me')
@UseGuards(AccessAuthGuard)
export class MeController {
  constructor(
    private readonly currentUser: CurrentUserService,
    private readonly presence: DriverPresenceService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Current user profile and role grants' })
  getMe(@CurrentActor() actor: RequestActor) {
    return this.currentUser.getProfile(actor.userId);
  }

  @Post('presence')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Upsert driver presence (online/offline + optional lat/lng). Used by dispatch to filter offline drivers when a presence row exists.',
  })
  setPresence(@CurrentActor() actor: RequestActor, @Body() dto: UpsertPresenceDto) {
    return this.presence.upsert(actor.userId, {
      online: dto.online,
      lat: dto.lat,
      lng: dto.lng,
    });
  }

  @Get('presence')
  @ApiOperation({ summary: 'Get current driver presence, if any' })
  getPresence(@CurrentActor() actor: RequestActor) {
    return this.presence.get(actor.userId);
  }
}
