import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { authError } from './auth-error.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { EMAIL_VERIFICATION_TTL_MS, IDENTITY_REPOSITORY, MAIL_SENDER } from './identity.constants.js';
import { UniqueConflictError, type IdentityRepository } from './identity.repository.js';
import type { MailSender } from '../../integrations/email/mail-sender.js';
import { normalizeEmail } from './phone-number.js';
import { accessSecret, fixedEqual, hashOneTimeSecret, randomSecret } from '../../platform/security/token-crypto.js';

@Injectable()
export class EmailVerificationService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly authMethods: AuthMethodPolicyService,
  ) {}

  async request(userId: string, rawEmail: string): Promise<{ verificationId: string; expiresAt: string }> {
    await this.authMethods.assertEnabled('EMAIL_LOGIN_IDENTIFIER');
    const email = normalizeEmail(rawEmail);
    const user = await this.repository.findUserById(userId);
    if (!user) {
      throw authError(401, 'UNAUTHORIZED', 'Authentication required');
    }

    const taken = await this.repository.findUserByEmail(email);
    if (taken && taken.id !== userId) {
      throw authError(409, 'EMAIL_IN_USE', 'Email is already in use');
    }

    const token = randomSecret();
    const expiresAt = new Date(Date.now() + EMAIL_VERIFICATION_TTL_MS);
    const verification = await this.repository.createEmailVerification({
      userId,
      email,
      tokenHash: hashOneTimeSecret(token, this.pepper()),
      expiresAt,
    });
    await this.mail.sendEmailVerification({
      email,
      verificationId: verification.id,
      token,
    });
    return { verificationId: verification.id, expiresAt: expiresAt.toISOString() };
  }

  async confirm(verificationId: string, token: string): Promise<{ verified: true }> {
    const verification = await this.repository.findEmailVerification(verificationId);
    if (!verification || verification.consumedAt) {
      throw authError(401, 'AUTH_EMAIL_TOKEN_INVALID', 'Email verification token is invalid');
    }
    if (verification.expiresAt <= new Date()) {
      throw authError(401, 'AUTH_EMAIL_TOKEN_EXPIRED', 'Email verification token has expired');
    }
    if (!fixedEqual(hashOneTimeSecret(token, this.pepper()), verification.tokenHash)) {
      throw authError(401, 'AUTH_EMAIL_TOKEN_INVALID', 'Email verification token is invalid');
    }

    const consumed = await this.repository.consumeEmailVerification(verification.id, new Date());
    if (!consumed) {
      throw authError(401, 'AUTH_EMAIL_TOKEN_INVALID', 'Email verification token is invalid');
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

  private pepper(): string {
    return accessSecret({
      JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
    });
  }
}
