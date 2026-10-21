import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { authError } from './auth-error.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { ensureActiveCustomerGrant } from './customer-grant.js';
import { IDENTITY_REPOSITORY, MAX_PHONE_ATTEMPTS, PHONE_CHALLENGE_TTL_MS, SMS_SENDER } from './identity.constants.js';
import { UniqueConflictError, type IdentityRepository, type UserRecord } from './identity.repository.js';
import { normalizePhone } from './phone-number.js';
import { SessionService, type SessionResult } from './session.service.js';
import type { SmsSender } from '../../integrations/sms/sms-sender.js';
import { accessSecret, fixedEqual, hashOneTimeSecret, randomOtpCode } from '../../platform/security/token-crypto.js';

@Injectable()
export class PhoneAuthService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    @Inject(SMS_SENDER) private readonly sms: SmsSender,
    private readonly sessions: SessionService,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly authMethods: AuthMethodPolicyService,
  ) {}

  async createChallenge(rawPhone: string): Promise<{ challengeId: string; expiresAt: string }> {
    await this.authMethods.assertEnabled('PHONE_SMS');
    const phone = normalizePhone(rawPhone);
    if (!phone) {
      throw authError(400, 'VALIDATION_ERROR', 'Phone must be a valid E.164 number');
    }

    // Unknown phones get no user row until the OTP proves ownership (see verify).
    const existing = await this.repository.findUserByPhone(phone);
    const code = randomOtpCode();
    const expiresAt = new Date(Date.now() + PHONE_CHALLENGE_TTL_MS);
    const challenge = await this.repository.createPhoneChallenge({
      userId: existing?.id ?? null,
      phone,
      codeHash: hashOneTimeSecret(code, this.pepper()),
      expiresAt,
    });
    await this.sms.sendOtp(phone, code);
    return { challengeId: challenge.id, expiresAt: expiresAt.toISOString() };
  }

  async verify(challengeId: string, code: string): Promise<SessionResult> {
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
    }
    const user = await this.repository.markPhoneVerified(owner.id, new Date());
    return this.sessions.issue(user, 'customer');
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
