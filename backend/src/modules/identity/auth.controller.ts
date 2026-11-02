import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { PhoneOtpThrottlerGuard } from './phone-otp-throttler.guard.js';
import type { AuthenticationResponseJSON, RegistrationResponseJSON } from '@simplewebauthn/server';
import {
  AccessAuthGuard,
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from './access-auth.guard.js';
import {
  AuthenticationVerifyDto,
  ConfirmEmailDto,
  EmailPasswordLoginDto,
  EmailPasswordRegisterDto,
  EmailVerificationDto,
  PasskeySignupVerifyDto,
  PasswordResetConfirmDto,
  PasswordResetRequestDto,
  PhoneChallengeDto,
  RefreshSessionDto,
  RegistrationVerifyDto,
  VerifyCodeDto,
} from './auth.dto.js';
import { AuthMethodEnabledGuard, RequireAuthMethod } from './auth-method-enabled.guard.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { EmailPasswordAuthService } from './email-password-auth.service.js';
import { EmailVerificationService } from './email-verification.service.js';
import { PasskeyService } from './passkey.service.js';
import { PasswordResetService } from './password-reset.service.js';
import { PhoneAuthService } from './phone-auth.service.js';
import { SessionService } from './session.service.js';

@ApiTags('identity')
@Controller('v1/auth')
@UseGuards(AuthMethodEnabledGuard)
export class AuthController {
  constructor(
    private readonly phoneAuth: PhoneAuthService,
    private readonly emailVerification: EmailVerificationService,
    private readonly emailPasswordAuth: EmailPasswordAuthService,
    private readonly passwordReset: PasswordResetService,
    private readonly passkeys: PasskeyService,
    private readonly sessions: SessionService,
    private readonly authMethods: AuthMethodPolicyService,
  ) {}

  @Get('methods')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Sign-in methods that are currently enabled (disabled ones are omitted)',
  })
  listMethods() {
    return this.authMethods.listPublic();
  }

  // Throttler uses Redis storage when REDIS_URL is set; otherwise in-memory (single process).
  @Post('phone/challenges')
  @RequireAuthMethod('PHONE_SMS')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard, PhoneOtpThrottlerGuard)
  @ApiOperation({
    summary: 'Start phone OTP challenge (rate limited per IP and 5 per phone per 15 min)',
  })
  createPhoneChallenge(@Body() body: PhoneChallengeDto) {
    return this.phoneAuth.createChallenge(body.phone);
  }

  @Post('phone/challenges/:id/verify')
  @RequireAuthMethod('PHONE_SMS')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary: 'Verify phone OTP and issue customer session (rate limited)',
  })
  verifyPhoneChallenge(@Param('id', ParseUUIDPipe) id: string, @Body() body: VerifyCodeDto) {
    return this.phoneAuth.verify(id, body.code);
  }

  @Post('email/register')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary:
      'Start email+password sign-up: emails a 6-digit code and returns a pending challenge (no account yet; same response for existing emails; rate limited). When AUTH_EMAIL_VERIFICATION_REQUIRED is off, a new address is signed up at once: the response adds verificationRequired=false and session.',
  })
  registerEmail(@Body() body: EmailPasswordRegisterDto) {
    return this.emailPasswordAuth.register({
      email: body.email,
      password: body.password,
      displayName: body.displayName,
    });
  }

  @Post('email/register/:id/verify')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary:
      'Verify an emailed code: a sign-up challenge creates the verified account; an activation challenge (from login) verifies the existing account. Issues a customer session (rate limited)',
  })
  verifyEmailRegistration(@Param('id', ParseUUIDPipe) id: string, @Body() body: VerifyCodeDto) {
    return this.emailPasswordAuth.verifyRegistration(id, body.code);
  }

  @Post('email/register/:id/resend')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary:
      'Email a new code for a sign-up or activation challenge (cooldown, send limit, refused once locked; rate limited)',
  })
  resendEmailRegistration(@Param('id', ParseUUIDPipe) id: string) {
    return this.emailPasswordAuth.resendRegistration(id);
  }

  @Post('email/login')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary:
      'Login with email and password. Unverified email + right password: 403 AUTH_EMAIL_NOT_VERIFIED with details {challengeId, expiresAt, resendAvailableAt} and an emailed code (rate limited)',
  })
  loginEmail(@Body() body: EmailPasswordLoginDto) {
    return this.emailPasswordAuth.login({
      email: body.email,
      password: body.password,
    });
  }

  @Post('email/verifications')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @HttpCode(HttpStatus.OK)
  @UseGuards(AccessAuthGuard)
  @ApiOperation({
    summary:
      'Email a 6-digit code verifying an address for the signed-in account (not used by sign-up). Repeats inside the resend cooldown return the live verification without mailing again',
  })
  requestEmailVerification(
    @CurrentActor() actor: RequestActor,
    @Body() body: EmailVerificationDto,
  ) {
    return this.emailVerification.request(actor.userId, body.email);
  }

  @Post('email/verifications/:id/confirm')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  confirmEmail(@Param('id', ParseUUIDPipe) id: string, @Body() body: ConfirmEmailDto) {
    return this.emailVerification.confirm(id, body.code);
  }

  @Post('email/password-resets')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary:
      'Forgot password: emails a 6-digit code and returns {challengeId, expiresAt, resendAvailableAt}; same response for unknown emails; per-email hourly cap (DEC-PROD-045)',
  })
  requestPasswordReset(@Body() body: PasswordResetRequestDto) {
    return this.passwordReset.request(body.email);
  }

  @Post('email/password-resets/:id/resend')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary: 'Email a new reset code (cooldown, send cap, refused once locked)',
  })
  resendPasswordReset(@Param('id', ParseUUIDPipe) id: string) {
    return this.passwordReset.resend(id);
  }

  @Post('email/password-resets/:id/confirm')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary:
      'Set a new password with the emailed code; wrong codes lock the challenge; revokes customer sessions',
  })
  confirmPasswordReset(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: PasswordResetConfirmDto,
  ) {
    return this.passwordReset.confirm(id, body.code, body.password);
  }

  @Post('passkeys/registration/options')
  @RequireAuthMethod('PASSKEY')
  @HttpCode(HttpStatus.OK)
  @UseGuards(CustomerSessionGuard)
  registrationOptions(@CurrentActor() actor: RequestActor) {
    return this.passkeys.registrationOptions(actor.userId);
  }

  @Post('passkeys/registration/verify')
  @RequireAuthMethod('PASSKEY')
  @HttpCode(HttpStatus.OK)
  @UseGuards(CustomerSessionGuard)
  verifyRegistration(@CurrentActor() actor: RequestActor, @Body() body: RegistrationVerifyDto) {
    return this.passkeys.verifyRegistration(
      actor.userId,
      body as unknown as RegistrationResponseJSON,
    );
  }

  @Post('passkeys/authentication/options')
  @RequireAuthMethod('PASSKEY')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary: 'Generate passkey authentication options (rate limited)',
  })
  authenticationOptions() {
    return this.passkeys.authenticationOptions();
  }

  @Post('passkeys/authentication/verify')
  @RequireAuthMethod('PASSKEY')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary: 'Verify passkey assertion and issue customer session (rate limited)',
  })
  verifyAuthentication(@Body() body: AuthenticationVerifyDto) {
    return this.passkeys.verifyAuthentication(
      body.ceremonyId,
      body as unknown as AuthenticationResponseJSON,
    );
  }

  @Post('passkeys/signup/options')
  @RequireAuthMethod('PASSKEY')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({ summary: 'Start contact-less passkey account registration' })
  signupOptions() {
    return this.passkeys.signupOptions();
  }

  @Post('passkeys/signup/verify')
  @RequireAuthMethod('PASSKEY')
  @HttpCode(HttpStatus.OK)
  @UseGuards(ThrottlerGuard)
  @ApiOperation({
    summary: 'Create a customer account from a verified passkey',
  })
  verifySignup(@Body() body: PasskeySignupVerifyDto) {
    return this.passkeys.verifySignup(body.ceremonyId, body as unknown as RegistrationResponseJSON);
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
