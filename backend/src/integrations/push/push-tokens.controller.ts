import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  AccessAuthGuard,
  CurrentActor,
  type RequestActor,
} from '../../modules/identity/access-auth.guard.js';
import { RegisterPushTokenDto } from '../../modules/identity/push-token.dto.js';
import { PushTokenService } from './push-token.service.js';

@ApiTags('push')
@ApiBearerAuth()
@Controller('v1/me/push-tokens')
@UseGuards(AccessAuthGuard)
export class PushTokensController {
  constructor(private readonly tokens: PushTokenService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Register an FCM device token for the current user' })
  register(@CurrentActor() actor: RequestActor, @Body() dto: RegisterPushTokenDto) {
    return this.tokens.register(actor.userId, dto.token, dto.platform ?? 'unknown');
  }
}
