import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { AppReviewLoginService } from './app-review-login.service.js';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import type { MailSender } from '../../integrations/email/mail-sender.js';
import { PasswordHasher } from '../../platform/security/password-hasher.js';
import {
  accessSecret,
  fixedEqual,
  hashOneTimeSecret,
  randomOtpCode,
  randomSecret,
} from '../../platform/security/token-crypto.js';
import { authError } from './auth-error.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { ensureActiveCustomerGrant } from './customer-grant.js';
import {
  EMAIL_SIGNUP_MAX_ATTEMPTS,
  EMAIL_SIGNUP_MAX_PER_HOUR,
  EMAIL_SIGNUP_MAX_SENDS,
  EMAIL_SIGNUP_RESEND_COOLDOWN_MS,
  EMAIL_SIGNUP_TTL_MS,
  IDENTITY_REPOSITORY,
  MAIL_SENDER,
} from './identity.constants.js';
import {
  UniqueConflictError,
  type EmailSignupChallengeRecord,
  type IdentityRepository,
  type UserRecord,
} from './identity.repository.js';
import { normalizeEmail } from './phone-number.js';
import { MailDeliveryError } from '../../integrations/email/mail-sender.js';
import { mailSenderStatus } from '../../integrations/email/dynamic-mail-sender.js';
import { captureServerError } from '../../platform/observability/sentry.js';
import { SessionService, type SessionResult } from './session.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';

export type EmailPasswordRegisterInput = {
  email: string;
  password: string;
  displayName?: string;
};

export type EmailSignupChallengeView = {
  challengeId: string;
  expiresAt: string;
  resendAvailableAt: string;
};

/** Register response when AUTH_EMAIL_VERIFICATION_REQUIRED is off: signed in at once. */
export type EmailSignupInstantView = EmailSignupChallengeView & {
  verificationRequired: false;
  session: SessionResult;
};

export type EmailPasswordLoginInput = {
  email: string;
  password: string;
};

const HOUR_MS = 60 * 60 * 1000;

/**
 * Email+password sign-up is a two-step OTP flow, mirroring phone sign-up: the account,
 * credential, CUSTOMER grant and session exist only after the emailed code is verified.
 * The same challenges (purpose ACTIVATE_EXISTING) verify accounts created before OTP
 * sign-up existed: login with the right password mails a code instead of a session.
 * Wrong attempts count per challenge (resends do not reset them); a locked challenge
 * cannot be resent, so the user starts a new one, which counts toward the hourly cap.
 *
 * The code is mailed after the challenge is returned, never awaited on the request path.
 */
@Injectable()
export class EmailPasswordAuthService {
  private readonly logger = new Logger(EmailPasswordAuthService.name);

  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    private readonly sessions: SessionService,
    private readonly passwords: PasswordHasher,
    private readonly authMethods: AuthMethodPolicyService,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    private readonly config: ConfigService<AppEnv, true>,
    @Optional() private readonly review?: AppReviewLoginService,
    @Optional() private readonly settings?: PlatformSettingsService,
  ) {
}

  /**
   * Responds identically whether or not the address already has an account; the
   * existing owner gets a notice email instead of a code, so verify can never succeed.
   */
  async register(
    input: EmailPasswordRegisterInput,
  ): Promise<EmailSignupChallengeView | EmailSignupInstantView> {
    await this.authMethods.assertEnabled('EMAIL_LOGIN_IDENTIFIER');
    const email = normalizeEmail(input.email);
    // Hash before any branching so both paths cost the same argon2 work.
    const passwordHash = await this.passwords.hash(input.password);

    const now = new Date();
    await this.assertHourlyCap(email, now);

    const existing = await this.repository.findUserByEmail(email);
    if (!existing && !(await this.verificationRequired())) {
      return this.registerWithoutVerification(email, passwordHash, input.displayName, now);
    }
    const reviewCode = existing ? null : await this.reviewCode(email);
    if (!reviewCode) {
      await this.assertMailTransport();
    }
    const code = reviewCode ?? randomOtpCode();
    const expiresAt = new Date(now.getTime() + EMAIL_SIGNUP_TTL_MS);
    const challenge = await this.repository.createEmailSignupChallenge({
      email,
      passwordHash: existing ? null : passwordHash,
      displayName: resolveDisplayName(input.displayName, email),
      codeHash: existing ? this.unusableCodeHash() : this.hashCode(code),
      expiresAt,
      sentAt: now,
    });

    if (!reviewCode) {
      this.sendLater(() =>
        existing
          ? this.mail.sendSignupAccountExists({ email })
          : this.mail.sendSignupCode({ email, code, expiresAt }),
      );
    }
    return toView(challenge);
  }

  /**
   * AUTH_EMAIL_VERIFICATION_REQUIRED = false: no code is mailed; the account is created
   * now with the email left unverified (it can still be verified later from the profile)
   * and the session comes back with the usual challenge fields. The challenge row is
   * stored already consumed with an unusable code, so verify/resend on it always fail.
   * An address that already has an account keeps the normal path (notice email), so
   * account existence is still not revealed.
   */
  private async registerWithoutVerification(
    email: string,
    passwordHash: string,
    displayName: string | undefined,
    now: Date,
  ): Promise<EmailSignupInstantView> {
    let user;
    try {
      user = await this.repository.createEmailPasswordUser({
        email,
        displayName: resolveDisplayName(displayName, email),
        passwordHash,
        verifiedAt: null,
      });
    } catch (error) {
      if (error instanceof UniqueConflictError) {
        throw authError(409, 'EMAIL_IN_USE', 'Email is already in use');
      }
      throw error;
    }
    const challenge = await this.repository.createEmailSignupChallenge({
      email,
      passwordHash: null,
      displayName: user.displayName ?? resolveDisplayName(displayName, email),
      codeHash: this.unusableCodeHash(),
      expiresAt: now,
      sentAt: now,
    });
    await this.repository.consumeEmailSignupChallenge(challenge.id, now);
    const session = await this.sessions.issue(user, 'customer');
    return { ...toView(challenge), verificationRequired: false, session };
  }

  /** Admin toggle; defaults to required when settings are unavailable or unreadable. */
  async verificationRequired(): Promise<boolean> {
    if (!this.settings) return true;
    try {
      return await this.settings.getBoolean('AUTH_EMAIL_VERIFICATION_REQUIRED');
    } catch {
      return true;
    }
  }

  async verifyRegistration(challengeId: string, code: string): Promise<SessionResult> {
    await this.authMethods.assertEnabled('EMAIL_LOGIN_IDENTIFIER');
    const challenge = await this.repository.findEmailSignupChallenge(challengeId);
    if (!challenge || challenge.consumedAt) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }
    if (challenge.attemptCount >= EMAIL_SIGNUP_MAX_ATTEMPTS) {
      throw authError(429, 'AUTH_CODE_LOCKED', 'Verification code is locked');
    }
    if (challenge.expiresAt <= new Date()) {
      throw authError(401, 'AUTH_CODE_EXPIRED', 'Verification code has expired');
    }
    if (!fixedEqual(this.hashCode(code), challenge.codeHash)) {
      const updated = await this.repository.recordFailedEmailSignupAttempt(challenge.id);
      if (updated.attemptCount >= EMAIL_SIGNUP_MAX_ATTEMPTS) {
        throw authError(429, 'AUTH_CODE_LOCKED', 'Verification code is locked');
      }
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }

    const consumed = await this.repository.consumeEmailSignupChallenge(challenge.id, new Date());
    if (!consumed) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }
    if (await this.review?.matches('email', challenge.email)) {
      const session = await (challenge.purpose === 'ACTIVATE_EXISTING'
        ? this.activateExistingUser(challenge)
        : this.createRegisteredUser(challenge));
      await this.review?.recordSignIn(session.user.id, 'email');
      return session;
    }
    if (challenge.purpose === 'ACTIVATE_EXISTING') {
      return this.activateExistingUser(challenge);
    }
    return this.createRegisteredUser(challenge);
  }

  private async createRegisteredUser(challenge: EmailSignupChallengeRecord): Promise<SessionResult> {
    if (!challenge.passwordHash) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }

    let user;
    try {
      user = await this.repository.createEmailPasswordUser({
        email: challenge.email,
        displayName: challenge.displayName,
        passwordHash: challenge.passwordHash,
        verifiedAt: new Date(),
      });
    } catch (error) {
      // Another sign-up or profile change claimed the address after the challenge started.
      // The caller has just proven they own the mailbox, so naming the conflict is safe.
      if (error instanceof UniqueConflictError) {
        throw authError(409, 'EMAIL_IN_USE', 'Email is already in use');
      }
      throw error;
    }
    return this.sessions.issue(user, 'customer');
  }

  async resendRegistration(challengeId: string): Promise<EmailSignupChallengeView> {
    await this.authMethods.assertEnabled('EMAIL_LOGIN_IDENTIFIER');
    const challenge = await this.repository.findEmailSignupChallenge(challengeId);
    if (!challenge || challenge.consumedAt) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }
    if (challenge.attemptCount >= EMAIL_SIGNUP_MAX_ATTEMPTS) {
      throw authError(429, 'AUTH_CODE_LOCKED', 'Verification code is locked; start again');
    }
    const now = new Date();
    if (challenge.lastSentAt.getTime() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS > now.getTime()) {
      throw resendCooldown();
    }
    if (challenge.sendCount >= EMAIL_SIGNUP_MAX_SENDS) {
      throw authError(429, 'AUTH_OTP_RESEND_LIMIT', 'No more codes can be sent; start sign-up again');
    }

    const activation = challenge.purpose === 'ACTIVATE_EXISTING';
    const pending = activation || challenge.passwordHash !== null;
    const reviewCode = pending ? await this.reviewCode(challenge.email) : null;
    if (pending && !reviewCode) {
      await this.assertMailTransport();
    }
    const code = reviewCode ?? randomOtpCode();
    const expiresAt = new Date(now.getTime() + EMAIL_SIGNUP_TTL_MS);
    const reissued = await this.repository.reissueEmailSignupCode(challenge.id, {
      codeHash: pending ? this.hashCode(code) : this.unusableCodeHash(),
      expiresAt,
      sentAt: now,
      sentBefore: new Date(now.getTime() - EMAIL_SIGNUP_RESEND_COOLDOWN_MS),
      maxSends: EMAIL_SIGNUP_MAX_SENDS,
      maxAttempts: EMAIL_SIGNUP_MAX_ATTEMPTS,
    });
    if (!reissued) {
      // Lost a race with another resend, or a wrong guess just locked the challenge.
      const latest = await this.repository.findEmailSignupChallenge(challenge.id);
      if (latest && latest.attemptCount >= EMAIL_SIGNUP_MAX_ATTEMPTS) {
        throw authError(429, 'AUTH_CODE_LOCKED', 'Verification code is locked; start again');
      }
      throw resendCooldown();
    }
    // The account-exists notice is sent once; repeating it would only help someone spam the owner.
    if (pending && !reviewCode) {
      this.sendLater(() =>
        this.mail.sendSignupCode({
          email: challenge.email,
          code,
          expiresAt,
          purpose: activation ? 'activation' : 'signup',
        }),
      );
    }
    return toView(reissued);
  }

  async login(input: EmailPasswordLoginInput): Promise<SessionResult> {
    await this.authMethods.assertEnabled('EMAIL_LOGIN_IDENTIFIER');
    const email = normalizeEmail(input.email);
    const user = await this.repository.findUserByEmail(email);
    const credential = user ? await this.repository.findCustomerCredential(user.id) : null;
    const passwordMatches = await this.passwords.verifyPresented(
      credential?.passwordHash ?? null,
      input.password,
    );
    if (!user || !passwordMatches) {
      throw authError(401, 'AUTH_INVALID_CREDENTIALS', 'Invalid email or password');
    }
    // Only reachable with the right password, so it does not leak account existence.
    // Accounts created before OTP sign-up get a code here (password reset also verifies).
    if (!user.emailVerifiedAt && (await this.verificationRequired())) {
      const challenge = await this.startActivation(user, email);
      throw authError(
        403,
        'AUTH_EMAIL_NOT_VERIFIED',
        'Email address is not verified; a verification code was sent',
        toView(challenge),
      );
    }
    return this.sessions.issue(user, 'customer');
  }

  /**
   * Reuses a live activation challenge still inside its resend cooldown, so repeated
   * logins do not mail a code each time; otherwise starts one under the hourly cap.
   */
  private async startActivation(
    user: UserRecord,
    email: string,
  ): Promise<EmailSignupChallengeRecord> {
    const now = new Date();
    const latest = await this.repository.findLatestEmailSignupChallenge(email);
    if (
      latest &&
      latest.purpose === 'ACTIVATE_EXISTING' &&
      latest.userId === user.id &&
      !latest.consumedAt &&
      latest.attemptCount < EMAIL_SIGNUP_MAX_ATTEMPTS &&
      latest.expiresAt > now &&
      latest.lastSentAt.getTime() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS > now.getTime()
    ) {
      return latest;
    }
    await this.assertHourlyCap(email, now);

    const reviewCode = await this.reviewCode(email);
    if (!reviewCode) {
      await this.assertMailTransport();
    }
    const code = reviewCode ?? randomOtpCode();
    const expiresAt = new Date(now.getTime() + EMAIL_SIGNUP_TTL_MS);
    const challenge = await this.repository.createEmailSignupChallenge({
      purpose: 'ACTIVATE_EXISTING',
      userId: user.id,
      email,
      passwordHash: null,
      displayName: user.displayName,
      codeHash: this.hashCode(code),
      expiresAt,
      sentAt: now,
    });
    if (!reviewCode) {
      this.sendLater(() =>
        this.mail.sendSignupCode({ email, code, expiresAt, purpose: 'activation' }),
      );
    }
    return challenge;
  }

  private async activateExistingUser(challenge: EmailSignupChallengeRecord): Promise<SessionResult> {
    const user = challenge.userId ? await this.repository.findUserById(challenge.userId) : null;
    // The address may have changed since the code was sent; the code only proves the old one.
    if (!user || user.email !== challenge.email) {
      throw authError(401, 'AUTH_CODE_INVALID', 'Verification code is invalid');
    }
    let verified = user;
    if (!user.emailVerifiedAt) {
      try {
        verified = await this.repository.setEmailVerified(user.id, challenge.email, new Date());
      } catch (error) {
        if (error instanceof UniqueConflictError) {
          throw authError(409, 'EMAIL_IN_USE', 'Email is already in use');
        }
        throw error;
      }
    }
    await ensureActiveCustomerGrant(this.repository, user.id);
    return this.sessions.issue(verified, 'customer');
  }

  private async assertHourlyCap(email: string, now: Date): Promise<void> {
    const recent = await this.repository.countEmailSignupChallengesSince(
      email,
      new Date(now.getTime() - HOUR_MS),
    );
    if (recent >= EMAIL_SIGNUP_MAX_PER_HOUR) {
      throw authError(429, 'AUTH_OTP_RATE_LIMITED', 'Too many verification codes for this email');
    }
  }

  private async reviewCode(email: string): Promise<string | null> {
    return (await this.review?.fixedCodeFor('email', email)) ?? null;
  }

  /** Reads the configured provider only, so a missing transport still fails before any mail. */
  private async assertMailTransport(): Promise<void> {
    const configured = await mailSenderStatus(this.mail)
      .then((status) => status.configured)
      // Settings unreadable: let the send itself report the failure after the response.
      .catch(() => true);
    if (!configured) {
      throw authError(503, 'EMAIL_DELIVERY_FAILED', 'Could not send the verification email');
    }
  }

  /**
   * Mails after the challenge is already on its way to the client: an SMTP round trip takes
   * seconds, and the app only needs the challenge to show the code screen. A failure is
   * logged (and captured to Sentry) instead of turning the response into an error; the user
   * can request another code once the resend cooldown passes.
   */
  private sendLater(send: () => Promise<void>): void {
    void send().catch((error: unknown) => this.reportMailFailure(error));
  }

  private reportMailFailure(error: unknown): void {
    const reason = error instanceof MailDeliveryError ? error.reason : 'unknown';
    const provider = error instanceof MailDeliveryError ? error.provider : 'unknown';
    const providerCode = error instanceof MailDeliveryError ? error.providerCode : undefined;
    this.logger.warn(
      `Sign-up email not sent: ${error instanceof Error ? error.message : 'unknown error'}`,
    );
    // A 5xx "rejected" reply means the mailbox/address itself was refused (e.g. SMTP 555 for a
    // non-ASCII local part): a client input problem, not an outage, so no Sentry event.
    if (reason === 'rejected') {
      return;
    }
    // Transient failures were already retried by the sender; report the original cause.
    captureServerError(error, {
      component: 'email_signup',
      mail_provider: provider,
      mail_reason: reason,
      mail_code: providerCode,
    });
  }

  private hashCode(code: string): string {
    return hashOneTimeSecret(code, this.pepper());
  }

  /** Hash of a secret nobody receives, so a challenge for an existing account never verifies. */
  private unusableCodeHash(): string {
    return hashOneTimeSecret(randomSecret(), this.pepper());
  }

  private pepper(): string {
    return accessSecret({
      JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
    });
  }
}

function toView(challenge: EmailSignupChallengeRecord): EmailSignupChallengeView {
  return {
    challengeId: challenge.id,
    expiresAt: challenge.expiresAt.toISOString(),
    resendAvailableAt: new Date(
      challenge.lastSentAt.getTime() + EMAIL_SIGNUP_RESEND_COOLDOWN_MS,
    ).toISOString(),
  };
}

function resendCooldown() {
  return authError(429, 'AUTH_OTP_RESEND_COOLDOWN', 'Wait before requesting another code');
}

function resolveDisplayName(rawDisplayName: string | undefined, email: string): string {
  const trimmed = rawDisplayName?.trim();
  if (trimmed) {
    return trimmed;
  }
  const localPart = email.split('@')[0]?.trim();
  return localPart && localPart.length > 0 ? localPart : email;
}
