import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { authError } from './auth-error.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import {
  EMAIL_SIGNUP_MAX_ATTEMPTS,
  EMAIL_SIGNUP_MAX_PER_HOUR,
  EMAIL_SIGNUP_RESEND_COOLDOWN_MS,
  EMAIL_SIGNUP_TTL_MS,
  IDENTITY_REPOSITORY,
  MAIL_SENDER,
} from './identity.constants.js';
import {
  UniqueConflictError,
  type EmailVerificationRecord,
  type IdentityRepository,
} from './identity.repository.js';
import { MailDeliveryError, type MailSender } from '../../integrations/email/mail-sender.js';
import { normalizeEmail } from './phone-number.js';
import { captureServerError } from '../../platform/observability/sentry.js';
import {
  accessSecret,
  fixedEqual,
  hashOneTimeSecret,
  randomOtpCode,
} from '../../platform/security/token-crypto.js';

export type EmailVerificationView = {
  verificationId: string;
  expiresAt: string;
  resendAvailableAt: string;
};

const HOUR_MS = 60 * 60 * 1000;

/**
 * Proves a profile email address with an emailed 6-digit code. The address is written to the
 * account only on confirm. Repeated requests for the same address inside the resend cooldown
 * return the live verification instead of mailing again, and requests are capped per user per hour.
 */
@Injectable()
export class EmailVerificationService {
  private readonly logger = new Logger(EmailVerificationService.name);

  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly authMethods: AuthMethodPolicyService,
  ) {}

  async request(userId: string, rawEmail: string): Promise<EmailVerificationView> {
    await this.authMethods.assertEnabled('EMAIL_LOGIN_IDENTIFIER');
    const email = normalizeEmail(rawEmail);
    const user = await this.repository.findUserById(userId);
    if (!user) {
      throw authError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    if (user.email === email && user.emailVerifiedAt) {
      throw authError(409, 'EMAIL_ALREADY_VERIFIED', 'Email is already verified');
    }

    const taken = await this.repository.findUserByEmail(email);
    if (taken && taken.id !== userId) {
      throw authError(409, 'EMAIL_IN_USE', 'Email is already in use');
    }

    const now = new Date();
    const latest = await this.repository.findLatestEmailVerification(userId);
    if (latest && latest.email === email && isReusable(latest, now)) {
      return toView(latest);
    }
    const recent = await this.repository.countEmailVerificationsSince(
      userId,
      new Date(now.getTime() - HOUR_MS),
    );
    if (recent >= EMAIL_SIGNUP_MAX_PER_HOUR) {
      throw authError(429, 'AUTH_OTP_RATE_LIMITED', 'Too many verification codes; try again later');
    }

    const code = randomOtpCode();
    const expiresAt = new Date(now.getTime() + EMAIL_SIGNUP_TTL_MS);
    const verification = await this.repository.createEmailVerification({
      userId,
      email,
      tokenHash: this.hashCode(code),
      expiresAt,
      sentAt: now,
    });
    await this.deliver(() => this.mail.sendEmailVerification({ email, code, expiresAt }));
    return toView(verification);
  }

  async confirm(verificationId: string, code: string): Promise<{ verified: true }> {
    const verification = await this.repository.findEmailVerification(verificationId);
    if (!verification || verification.consumedAt) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }
    if (verification.attemptCount >= EMAIL_SIGNUP_MAX_ATTEMPTS) {
      throw authError(429, 'AUTH_CODE_LOCKED', 'Verification code is locked');
    }
    if (verification.expiresAt <= new Date()) {
      throw authError(401, 'AUTH_CODE_EXPIRED', 'Verification code has expired');
    }
    if (!fixedEqual(this.hashCode(code), verification.tokenHash)) {
      const updated = await this.repository.recordFailedEmailVerificationAttempt(verification.id);
      if (updated.attemptCount >= EMAIL_SIGNUP_MAX_ATTEMPTS) {
        throw authError(429, 'AUTH_CODE_LOCKED', 'Verification code is locked');
      }
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }

    const consumed = await this.repository.consumeEmailVerification(verification.id, new Date());
    if (!consumed) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }

    try {
      await this.repository.setEmailVerified(verification.userId, verification.email, new Date());
    } catch (error) {
      if (error instanceof UniqueConflictError) {
        throw authError(409, 'EMAIL_IN_USE', 'Email is already in use');
      }
      throw error;
    }
    return { verified: true };
  }

  private async deliver(send: () => Promise<void>): Promise<void> {
    try {
      await send();
    } catch (error) {
      const reason = error instanceof MailDeliveryError ? error.reason : 'unknown';
      this.logger.warn(
        `Email verification code not sent: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
      if (reason === 'rejected') {
        throw authError(400, 'EMAIL_ADDRESS_REJECTED', 'This email address cannot receive mail');
      }
      captureServerError(error, {
        component: 'email_verification',
        mail_provider: error instanceof MailDeliveryError ? error.provider : 'unknown',
        mail_reason: reason,
        mail_code: error instanceof MailDeliveryError ? error.providerCode : undefined,
      });
      throw authError(503, 'EMAIL_DELIVERY_FAILED', 'Could not send the verification email');
    }
  }

  private hashCode(code: string): string {
    return hashOneTimeSecret(
      code,
      accessSecret({
        JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
        NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
      }),
    );
  }
}

function isReusable(verification: EmailVerificationRecord, now: Date): boolean {
  return (
    !verification.consumedAt &&
    verification.attemptCount < EMAIL_SIGNUP_MAX_ATTEMPTS &&
    verification.expiresAt > now &&
    verification.lastSentAt.getTime() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS > now.getTime()
  );
}

function toView(verification: EmailVerificationRecord): EmailVerificationView {
  return {
    verificationId: verification.id,
    expiresAt: verification.expiresAt.toISOString(),
    resendAvailableAt: new Date(
      verification.lastSentAt.getTime() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS,
    ).toISOString(),
  };
}
