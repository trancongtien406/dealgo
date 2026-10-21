import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import type { MailSender } from '../../integrations/email/mail-sender.js';
import { PasswordHasher } from '../../platform/security/password-hasher.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import {
  accessSecret,
  fixedEqual,
  hashOneTimeSecret,
  randomOtpCode,
  randomSecret,
} from '../../platform/security/token-crypto.js';
import { authError } from './auth-error.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import {
  EMAIL_SIGNUP_MAX_SENDS,
  EMAIL_SIGNUP_RESEND_COOLDOWN_MS,
  IDENTITY_REPOSITORY,
  MAIL_SENDER,
} from './identity.constants.js';
import {
  UniqueConflictError,
  type IdentityRepository,
  type PasswordResetRecord,
} from './identity.repository.js';
import { normalizeEmail } from './phone-number.js';

export type PasswordResetChallengeView = {
  challengeId: string;
  expiresAt: string;
  resendAvailableAt: string;
};

const HOUR_MS = 60 * 60 * 1000;

/**
 * DEC-PROD-045 — forgot password by emailed 6-digit code, the same shape as sign-up OTP
 * (DEC-PROD-008). Code lifetime, wrong-code lock and per-address hourly cap are platform
 * settings (AUTH_PASSWORD_RESET_*); resend cooldown and send cap are shared with sign-up.
 *
 * The response never reveals whether the address has a password account: an unknown address
 * gets a decoy challenge (no user, unusable code, no email) that behaves like a real one.
 */
@Injectable()
export class PasswordResetService {
  private readonly logger = new Logger(PasswordResetService.name);

  constructor(
    @Inject(IDENTITY_REPOSITORY)
    private readonly repository: IdentityRepository,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    private readonly passwords: PasswordHasher,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly authMethods: AuthMethodPolicyService,
    private readonly settings: PlatformSettingsService,
  ) {}

  async request(rawEmail: string): Promise<PasswordResetChallengeView> {
    await this.authMethods.assertEnabled('EMAIL_LOGIN_IDENTIFIER');
    const email = normalizeEmail(rawEmail);
    const now = new Date();
    const limits = await this.limits();
    const recent = await this.repository.countPasswordResetsSince(
      email,
      new Date(now.getTime() - HOUR_MS),
    );
    if (recent >= limits.maxPerHour) {
      throw authError(429, 'AUTH_OTP_RATE_LIMITED', 'Too many reset codes for this email');
    }

    const user = await this.repository.findUserByEmail(email);
    const credential = user ? await this.repository.findCustomerCredential(user.id) : null;
    const eligible = Boolean(user && credential?.passwordHash);
    const code = randomOtpCode();
    const expiresAt = new Date(now.getTime() + limits.ttlMs);
    const reset = await this.repository.createPasswordReset({
      userId: eligible ? user!.id : null,
      email,
      tokenHash: eligible ? this.hashCode(code) : this.unusableHash(),
      expiresAt,
      sentAt: now,
    });
    if (eligible) {
      // Not awaited: SMTP latency on real accounts only would time-leak which addresses exist.
      void this.deliver(email, code, expiresAt, user!.id);
    }
    return toView(reset);
  }

  async resend(challengeId: string): Promise<PasswordResetChallengeView> {
    await this.authMethods.assertEnabled('EMAIL_LOGIN_IDENTIFIER');
    const limits = await this.limits();
    const reset = await this.repository.findPasswordReset(challengeId);
    if (!reset || reset.consumedAt) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Reset code is invalid');
    }
    if (reset.attemptCount >= limits.maxAttempts) {
      throw authError(429, 'AUTH_CODE_LOCKED', 'Reset code is locked; start again');
    }
    const now = new Date();
    if (reset.lastSentAt.getTime() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS > now.getTime()) {
      throw resendCooldown();
    }
    if (reset.sendCount >= EMAIL_SIGNUP_MAX_SENDS) {
      throw authError(429, 'AUTH_OTP_RESEND_LIMIT', 'No more codes can be sent; start again');
    }
    const code = randomOtpCode();
    const expiresAt = new Date(now.getTime() + limits.ttlMs);
    const reissued = await this.repository.reissuePasswordResetCode(reset.id, {
      tokenHash: reset.userId ? this.hashCode(code) : this.unusableHash(),
      expiresAt,
      sentAt: now,
      sentBefore: new Date(now.getTime() - EMAIL_SIGNUP_RESEND_COOLDOWN_MS),
      maxSends: EMAIL_SIGNUP_MAX_SENDS,
      maxAttempts: limits.maxAttempts,
    });
    if (!reissued) {
      const latest = await this.repository.findPasswordReset(reset.id);
      if (latest && latest.attemptCount >= limits.maxAttempts) {
        throw authError(429, 'AUTH_CODE_LOCKED', 'Reset code is locked; start again');
      }
      throw resendCooldown();
    }
    if (reset.userId) {
      void this.deliver(reset.email, code, expiresAt, reset.userId);
    }
    return toView(reissued);
  }

  async confirm(challengeId: string, code: string, newPassword: string): Promise<{ reset: true }> {
    await this.authMethods.assertEnabled('EMAIL_LOGIN_IDENTIFIER');
    const limits = await this.limits();
    const reset = await this.repository.findPasswordReset(challengeId);
    if (!reset || reset.consumedAt) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Reset code is invalid');
    }
    if (reset.attemptCount >= limits.maxAttempts) {
      throw authError(429, 'AUTH_CODE_LOCKED', 'Reset code is locked');
    }
    if (reset.expiresAt <= new Date()) {
      throw authError(401, 'AUTH_CODE_EXPIRED', 'Reset code has expired');
    }
    if (!fixedEqual(this.hashCode(code), reset.tokenHash)) {
      const updated = await this.repository.recordFailedPasswordResetAttempt(reset.id);
      if (updated.attemptCount >= limits.maxAttempts) {
        throw authError(429, 'AUTH_CODE_LOCKED', 'Reset code is locked');
      }
      throw authError(401, 'AUTH_CODE_INVALID', 'Reset code is invalid');
    }
    const user = reset.userId ? await this.repository.findUserById(reset.userId) : null;
    // The address may have changed since the code was sent; the code only proves the old one.
    if (!user || user.email !== reset.email) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Reset code is invalid');
    }
    if (!(await this.repository.consumePasswordReset(reset.id, new Date(), limits.maxAttempts))) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Reset code is invalid');
    }

    const now = new Date();
    await this.repository.saveCustomerCredential(user.id, await this.passwords.hash(newPassword));
    // A stolen refresh token must not outlive the password it was issued under.
    await this.repository.revokeUserSessions(user.id, 'CUSTOMER', now);
    // The code reached this inbox, which proves control of the address.
    if (user.email && !user.emailVerifiedAt) {
      try {
        await this.repository.setEmailVerified(user.id, user.email, now);
      } catch (error) {
        if (!(error instanceof UniqueConflictError)) {
          throw error;
        }
      }
    }
    return { reset: true };
  }

  private async limits(): Promise<{ ttlMs: number; maxAttempts: number; maxPerHour: number }> {
    const [ttlMinutes, maxAttempts, maxPerHour] = await Promise.all([
      this.settings.getNumber('AUTH_PASSWORD_RESET_CODE_TTL_MINUTES'),
      this.settings.getNumber('AUTH_PASSWORD_RESET_MAX_ATTEMPTS'),
      this.settings.getNumber('AUTH_PASSWORD_RESET_MAX_PER_HOUR'),
    ]);
    return { ttlMs: ttlMinutes * 60_000, maxAttempts, maxPerHour };
  }

  /**
   * Delivery failure is logged, not surfaced: a 503 only for real accounts would reveal which
   * addresses have one. The user can resend after the cooldown.
   */
  private async deliver(email: string, code: string, expiresAt: Date, userId: string): Promise<void> {
    try {
      await this.mail.sendPasswordResetCode({ email, code, expiresAt });
    } catch (error) {
      this.logger.warn(
        `Password reset code not sent for user ${userId}: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }
  }

  private hashCode(code: string): string {
    return hashOneTimeSecret(code, this.pepper());
  }

  private unusableHash(): string {
    return hashOneTimeSecret(randomSecret(), this.pepper());
  }

  private pepper(): string {
    return accessSecret({
      JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
    });
  }
}

function toView(reset: PasswordResetRecord): PasswordResetChallengeView {
  return {
    challengeId: reset.id,
    expiresAt: reset.expiresAt.toISOString(),
    resendAvailableAt: new Date(
      reset.lastSentAt.getTime() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS,
    ).toISOString(),
  };
}

function resendCooldown() {
  return authError(429, 'AUTH_OTP_RESEND_COOLDOWN', 'Wait before requesting another code');
}
