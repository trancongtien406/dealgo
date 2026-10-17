import { Body, Controller, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import type { AuthenticationResponseJSON, RegistrationResponseJSON } from '@simplewebauthn/server';
import { AccessAuthGuard, CurrentActor, CustomerSessionGuard, type RequestActor } from './access-auth.guard.js';
import {
  AuthenticationVerifyDto,
  ConfirmEmailDto,
  EmailVerificationDto,
  PasskeyAuthenticationOptionsDto,
  PhoneChallengeDto,
  RefreshSessionDto,
  RegistrationVerifyDto,
  VerifyCodeDto,
} from './auth.dto.js';
import { EmailVerificationService } from './email-verification.service.js';
import { PasskeyService } from './passkey.service.js';
import { PhoneAuthService } from './phone-auth.service.js';
import { SessionService } from './session.service.js';

@ApiTags('identity')
@Controller('v1/auth')
export class AuthController {
  constructor(
    private readonly phoneAuth: PhoneAuthService,
    private readonly emailVerification: EmailVerificationService,
    private readonly passkeys: PasskeyService,
    private readonly sessions: SessionService,
  ) {}

  // Throttler uses Redis storage when REDIS_URL is set; otherwise in-memory (single process).
  @Post('phone/challenges')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({ summary: 'Start phone OTP challenge (rate limited)' })
  createPhoneChallenge(@Body() body: PhoneChallengeDto) {
    return this.phoneAuth.createChallenge(body.phone);
  }

  @Post('phone/challenges/:id/verify')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({ summary: 'Verify phone OTP and issue customer session (rate limited)' })
  verifyPhoneChallenge(@Param('id', ParseUUIDPipe) id: string, @Body() body: VerifyCodeDto) {
    return this.phoneAuth.verify(id, body.code);
  }

  @Post('email/verifications')
  @HttpCode(HttpStatus.OK)
  @UseGuards(AccessAuthGuard)
  requestEmailVerification(@CurrentActor() actor: RequestActor, @Body() body: EmailVerificationDto) {
    return this.emailVerification.request(actor.userId, body.email);
  }

  @Post('email/verifications/:id/confirm')
  @HttpCode(HttpStatus.OK)
  confirmEmail(@Param('id', ParseUUIDPipe) id: string, @Body() body: ConfirmEmailDto) {
    return this.emailVerification.confirm(id, body.token);
  }

  @Post('passkeys/registration/options')
  @HttpCode(HttpStatus.OK)
  @UseGuards(CustomerSessionGuard)
  registrationOptions(@CurrentActor() actor: RequestActor) {
    return this.passkeys.registrationOptions(actor.userId);
  }

  @Post('passkeys/registration/verify')
  @HttpCode(HttpStatus.OK)
  @UseGuards(CustomerSessionGuard)
  verifyRegistration(@CurrentActor() actor: RequestActor, @Body() body: RegistrationVerifyDto) {
    return this.passkeys.verifyRegistration(actor.userId, body as unknown as RegistrationResponseJSON);
  }

  @Post('passkeys/authentication/options')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({ summary: 'Generate passkey authentication options (rate limited)' })
  authenticationOptions(@Body() body: PasskeyAuthenticationOptionsDto) {
    return this.passkeys.authenticationOptions(body.phone);
  }

  @Post('passkeys/authentication/verify')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({ summary: 'Verify passkey assertion and issue customer session (rate limited)' })
  verifyAuthentication(@Body() body: AuthenticationVerifyDto) {
    return this.passkeys.verifyAuthentication(body as unknown as AuthenticationResponseJSON);
  }

  @Post('sessions/refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() body: RefreshSessionDto) {
    return this.sessions.refresh(body.refreshToken);
  }

  @Post('sessions/revoke')
  @HttpCode(HttpStatus.OK)
  @UseGuards(AccessAuthGuard)
  revoke(@CurrentActor() actor: RequestActor) {
    return this.sessions.revoke(actor.sessionId);
  }
}
