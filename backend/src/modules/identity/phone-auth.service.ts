import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { SmsDeliveryError } from '../../integrations/sms/sms-errors.js';
import { AppReviewLoginService } from './app-review-login.service.js';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { authError } from './auth-error.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { ensureActiveCustomerGrant } from './customer-grant.js';
import {
  IDENTITY_REPOSITORY,
  MAX_ACCOUNTS_PER_DEVICE,
  MAX_PHONE_ATTEMPTS,
  PHONE_CHALLENGE_TTL_MS,
  SMS_SENDER,
} from './identity.constants.js';
import { UniqueConflictError, type IdentityRepository, type UserRecord } from './identity.repository.js';
import { normalizePhone } from './phone-number.js';
import { SessionService, type SessionResult } from './session.service.js';
import type { SmsSender } from '../../integrations/sms/sms-sender.js';
import { accessSecret, fixedEqual, hashOneTimeSecret, randomOtpCode } from '../../platform/security/token-crypto.js';

@Injectable()
export class PhoneAuthService {
  private readonly logger = new Logger(PhoneAuthService.name);

  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    @Inject(SMS_SENDER) private readonly sms: SmsSender,
    private readonly sessions: SessionService,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly authMethods: AuthMethodPolicyService,
    @Optional() private readonly review?: AppReviewLoginService,
    @Optional() private readonly platformSettings?: PlatformSettingsService,
  ) {}

  async createChallenge(
    rawPhone: string,
    clientContext?: { deviceId?: string | null; ipAddress?: string | null },
  ): Promise<{ challengeId: string; expiresAt: string }> {
    await this.authMethods.assertEnabled('PHONE_SMS');
    const phone = normalizePhone(rawPhone);
    if (!phone) {
      throw authError(400, 'VALIDATION_ERROR', 'Phone must be a valid E.164 number');
    }

    // Unknown phones get no user row until the OTP proves ownership (see verify).
    const existing = await this.repository.findUserByPhone(phone);
    if (!existing && clientContext?.deviceId) {
      const maxLimit = (await this.platformSettings?.getNumber('MAX_ACCOUNTS_PER_DEVICE')) ?? MAX_ACCOUNTS_PER_DEVICE;
      const regCount = await this.repository.countRegistrationsByDeviceId(clientContext.deviceId);
      if (regCount >= maxLimit) {
        throw authError(
          429,
          'AUTH_DEVICE_REGISTRATION_LIMIT',
          'Thiết bị này đã vượt quá số lượng tài khoản được phép đăng ký',
        );
      }
    }
    const reviewCode = (await this.review?.fixedCodeFor('phone', phone)) ?? null;
    const code = reviewCode ?? randomOtpCode();
    const expiresAt = new Date(Date.now() + PHONE_CHALLENGE_TTL_MS);
    const challenge = await this.repository.createPhoneChallenge({
      userId: existing?.id ?? null,
      phone,
      codeHash: hashOneTimeSecret(code, this.pepper()),
      expiresAt,
    });
    if (!reviewCode) {
      await this.sendOtp(phone, code);
    }
    return { challengeId: challenge.id, expiresAt: expiresAt.toISOString() };
  }

  private async sendOtp(phone: string, code: string): Promise<void> {
    try {
      await this.sms.sendOtp(phone, code);
    } catch (error) {
      if (!(error instanceof SmsDeliveryError)) {
        throw error;
      }
      this.logger.warn(error.message);
      if (error.reason === 'invalid_phone') {
        throw authError(400, 'VALIDATION_ERROR', 'Phone number cannot receive SMS');
      }
      if (error.reason === 'rate_limited') {
        throw authError(429, 'AUTH_OTP_RATE_LIMITED', 'Too many verification codes for this phone');
      }
      throw authError(503, 'SMS_DELIVERY_FAILED', 'Could not send the verification SMS');
    }
  }

  async verify(
    challengeId: string,
    code: string,
    clientContext?: {
      deviceId?: string | null;
      deviceLabel?: string | null;
      userAgent?: string | null;
      ipAddress?: string | null;
    },
  ): Promise<SessionResult> {
    await this.authMethods.assertEnabled('PHONE_SMS');
    const challenge = await this.repository.findPhoneChallenge(challengeId);
    if (!challenge || challenge.consumedAt) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }
    if (challenge.attemptCount >= MAX_PHONE_ATTEMPTS) {
      throw authError(429, 'AUTH_CODE_LOCKED', 'Verification code is locked');
    }
    if (challenge.expiresAt <= new Date()) {
      throw authError(401, 'AUTH_CODE_EXPIRED', 'Verification code has expired');
    }

    const matches = fixedEqual(hashOneTimeSecret(code, this.pepper()), challenge.codeHash);
    if (!matches) {
      const updated = await this.repository.recordFailedPhoneAttempt(challenge.id);
      if (updated.attemptCount >= MAX_PHONE_ATTEMPTS) {
        throw authError(429, 'AUTH_CODE_LOCKED', 'Verification code is locked');
      }
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }

    const consumed = await this.repository.consumePhoneChallenge(challenge.id, new Date());
    if (!consumed) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }

    if (!challenge.userId && clientContext?.deviceId) {
      const existingUser = await this.repository.findUserByPhone(challenge.phone);
      if (!existingUser) {
        const regCount = await this.repository.countRegistrationsByDeviceId(clientContext.deviceId);
        if (regCount >= MAX_ACCOUNTS_PER_DEVICE) {
          throw authError(
            429,
            'AUTH_DEVICE_REGISTRATION_LIMIT',
            'Thiết bị này đã vượt quá số lượng tài khoản được phép đăng ký',
          );
        }
      }
    }

    const owner = challenge.userId
      ? await this.repository.findUserById(challenge.userId)
      : await this.findOrCreateByPhone(challenge.phone);
    if (!owner) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }
    // First successful OTP completes sign-up, including accounts left unverified by
    // the former flow that created the user at challenge time.
    if (!owner.phoneVerifiedAt) {
      await ensureActiveCustomerGrant(this.repository, owner.id);
      if (clientContext?.deviceId) {
        await this.repository.recordDeviceRegistration({
          deviceId: clientContext.deviceId,
          userId: owner.id,
          ipAddress: clientContext.ipAddress ?? null,
        });
      }
    }
    const user = await this.repository.markPhoneVerified(owner.id, new Date());
    if (await this.review?.matches('phone', challenge.phone)) {
      await this.review?.recordSignIn(user.id, 'phone');
    }
    return this.sessions.issue(user, 'customer', clientContext);
  }

  private async findOrCreateByPhone(phone: string): Promise<UserRecord> {
    const existing = await this.repository.findUserByPhone(phone);
    if (existing) {
      return existing;
    }
    try {
      return await this.repository.createUser({
        phone,
        email: null,
        displayName: 'DealGo user',
      });
    } catch (error) {
      if (!(error instanceof UniqueConflictError)) {
        throw error;
      }
      const raced = await this.repository.findUserByPhone(phone);
      if (!raced) {
        throw error;
      }
      return raced;
    }
  }

  private pepper(): string {
    return accessSecret({
      JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
    });
  }
}
