import {
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../../modules/identity/access-auth.guard.js';
import { VoiceService } from './voice.service.js';

@ApiTags('voice')
@ApiBearerAuth()
@Controller('v1/rides')
@UseGuards(CustomerSessionGuard)
export class RideVoiceController {
  constructor(private readonly voice: VoiceService) {}

  @Post(':rideId/voice-session')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Create an audio-only in-app voice session for a ride',
  })
  create(
    @CurrentActor() actor: RequestActor,
    @Param('rideId', ParseUUIDPipe) rideId: string,
  ) {
    return this.voice.createForRide(actor, rideId);
  }
}

@ApiTags('voice')
@ApiBearerAuth()
@Controller('v1/food/orders')
@UseGuards(CustomerSessionGuard)
export class FoodVoiceController {
  constructor(private readonly voice: VoiceService) {}

  @Post(':orderId/voice-session')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Create an audio-only in-app voice session for a food order',
  })
  create(
    @CurrentActor() actor: RequestActor,
    @Param('orderId', ParseUUIDPipe) orderId: string,
  ) {
    return this.voice.createForFood(actor, orderId);
  }
}
