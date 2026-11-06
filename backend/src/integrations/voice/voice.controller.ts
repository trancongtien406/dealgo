import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../../modules/identity/access-auth.guard.js';
import { VoiceService } from './voice.service.js';

/** Redialing a few times is normal; more is call spam (each ring rings the other phone). */
const VOICE_START_LIMIT_PER_MINUTE = 5;

@ApiTags('voice')
@ApiBearerAuth()
@Controller('v1/rides')
@UseGuards(CustomerSessionGuard)
export class RideVoiceController {
  constructor(private readonly voice: VoiceService) {}

  @Post(':rideId/calls')
  @HttpCode(HttpStatus.CREATED)
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: VOICE_START_LIMIT_PER_MINUTE, ttl: 60_000 } })
  @ApiOperation({
    summary:
      'Call the other party of an active ride (customer ↔ assigned driver): rings the callee, returns the caller’s audio-only LiveKit join token',
  })
  start(
    @CurrentActor() actor: RequestActor,
    @Param('rideId', ParseUUIDPipe) rideId: string,
  ) {
    return this.voice.startForRide(actor, rideId);
  }
}

@ApiTags('voice')
@ApiBearerAuth()
@Controller('v1/food/orders')
@UseGuards(CustomerSessionGuard)
export class FoodVoiceController {
  constructor(private readonly voice: VoiceService) {}

  @Post(':orderId/calls')
  @HttpCode(HttpStatus.CREATED)
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: VOICE_START_LIMIT_PER_MINUTE, ttl: 60_000 } })
  @ApiOperation({
    summary:
      'Call the other party of an active food order (customer ↔ assigned driver): rings the callee, returns the caller’s audio-only LiveKit join token',
  })
  start(
    @CurrentActor() actor: RequestActor,
    @Param('orderId', ParseUUIDPipe) orderId: string,
  ) {
    return this.voice.startForFood(actor, orderId);
  }
}

@ApiTags('voice')
@ApiBearerAuth()
@Controller('v1/calls')
@UseGuards(CustomerSessionGuard)
export class VoiceCallController {
  constructor(private readonly voice: VoiceService) {}

  @Get('config')
  @ApiOperation({ summary: 'Whether in-app calls are available (admin toggle and provider configured)' })
  config() {
    return this.voice.callConfig();
  }

  @Get(':callId')
  @ApiOperation({ summary: 'Current state of a call (caller or callee only)' })
  get(
    @CurrentActor() actor: RequestActor,
    @Param('callId', ParseUUIDPipe) callId: string,
  ) {
    return this.voice.get(actor, callId);
  }

  @Post(':callId/accept')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Answer a ringing call (callee only); returns the callee’s join token' })
  accept(
    @CurrentActor() actor: RequestActor,
    @Param('callId', ParseUUIDPipe) callId: string,
  ) {
    return this.voice.accept(actor, callId);
  }

  @Post(':callId/decline')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Decline a ringing call (callee only)' })
  decline(
    @CurrentActor() actor: RequestActor,
    @Param('callId', ParseUUIDPipe) callId: string,
  ) {
    return this.voice.decline(actor, callId);
  }

  @Post(':callId/end')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Hang up: cancelling while it rings records a missed call; a connected call ends',
  })
  end(
    @CurrentActor() actor: RequestActor,
    @Param('callId', ParseUUIDPipe) callId: string,
  ) {
    return this.voice.end(actor, callId);
  }
}
