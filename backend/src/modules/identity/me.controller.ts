import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AccessAuthGuard, CurrentActor, type RequestActor } from './access-auth.guard.js';
import { CurrentUserService } from './current-user.service.js';
import { DriverPresenceService } from './driver-presence.service.js';
import { UpdateMeDto } from './me.dto.js';
import { ReportLocationDto, UpsertPresenceDto } from './presence.dto.js';

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

  @Patch()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Update profile fields. Email changes start EmailVerification (do not set verified email directly).',
  })
  updateMe(@CurrentActor() actor: RequestActor, @Body() dto: UpdateMeDto) {
    return this.currentUser.updateProfile(actor.userId, {
      displayName: dto.displayName,
      email: dto.email,
      dateOfBirth: dto.dateOfBirth,
      gender: dto.gender,
    });
  }

  @Post('presence')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Upsert driver presence (online/offline, optional rideEnabled/foodEnabled, lat/lng). Dispatch lists are empty while offline or for a service switched off.',
  })
  setPresence(@CurrentActor() actor: RequestActor, @Body() dto: UpsertPresenceDto) {
    return this.presence.upsert(actor.userId, {
      online: dto.online,
      rideEnabled: dto.rideEnabled,
      foodEnabled: dto.foodEnabled,
      lat: dto.lat,
      lng: dto.lng,
    });
  }

  @Post('presence/location')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Driver location heartbeat (DEC-PROD-031). Updates lat/lng only; customers see it on an active ride/food order while it is under 2 minutes old.',
  })
  reportLocation(@CurrentActor() actor: RequestActor, @Body() dto: ReportLocationDto) {
    return this.presence.reportLocation(actor.userId, {
      lat: dto.lat,
      lng: dto.lng,
      ...(dto.heading !== undefined ? { heading: dto.heading } : {}),
      ...(dto.speedMps !== undefined ? { speedMps: dto.speedMps } : {}),
      ...(dto.accuracyM !== undefined ? { accuracyM: dto.accuracyM } : {}),
      ...(dto.recordedAt ? { recordedAt: new Date(dto.recordedAt) } : {}),
    });
  }

  @Get('presence')
  @ApiOperation({ summary: 'Get current driver presence, if any' })
  getPresence(@CurrentActor() actor: RequestActor) {
    return this.presence.get(actor.userId);
  }
}
