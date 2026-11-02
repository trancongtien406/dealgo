import { Injectable, Logger } from '@nestjs/common';

export interface MailSender {
  /** 6-digit code proving a profile email address (added, changed or never verified). */
  sendEmailVerification(input: EmailVerificationCodeMail): Promise<void>;
  /** DEC-PROD-045: 6-digit forgot-password code (the old link token is retired). */
  sendPasswordResetCode(input: PasswordResetCodeMail): Promise<void>;
  /** `purpose: 'activation'` verifies the email of an existing, never-verified account. */
  sendSignupCode(input: SignupCodeMail): Promise<void>;
  /** Sent instead of a code when someone tries to sign up with an address that already has an account. */
  sendSignupAccountExists(input: { email: string }): Promise<void>;
  /** Admin "send test email": proves the configured provider delivers. */
  sendTestEmail(input: { email: string }): Promise<void>;
  /** t82u: terms/privacy changed notice (bulk, sent by the outbox relay in paced batches). */
  sendPolicyUpdate(input: PolicyUpdateMail): Promise<void>;
}

export type PolicyUpdateMail = {
  email: string;
  /** e.g. "Điều khoản sử dụng". */
  documentTitle: string;
  version: number;
  effectiveAt: Date | null;
  changelog: string;
  url: string;
};

export type MailFailureReason = 'auth_failed' | 'rejected' | 'rate_limited' | 'provider_unavailable' | 'suppressed';

export class MailDeliveryError extends Error {
  constructor(
    readonly reason: MailFailureReason,
    readonly provider: string,
    readonly providerCode?: string,
  ) {
    super(`Email ${provider} failed: ${reason}${providerCode ? ` (${providerCode})` : ''}`);
    this.name = 'MailDeliveryError';
  }
}

export type EmailVerificationCodeMail = {
  email: string;
  code: string;
  expiresAt: Date;
};

export type PasswordResetCodeMail = {
  email: string;
  code: string;
  expiresAt: Date;
};

export type DeliveredPasswordReset = PasswordResetCodeMail;

export type SignupCodeMail = {
  email: string;
  code: string;
  expiresAt: Date;
  purpose?: 'signup' | 'activation';
};

export type DeliveredSignupCode = SignupCodeMail;

@Injectable()
export class MockMailSender implements MailSender {
  private readonly logger = new Logger(MockMailSender.name);
  readonly sent: EmailVerificationCodeMail[] = [];
  readonly passwordResets: DeliveredPasswordReset[] = [];
  readonly signupCodes: DeliveredSignupCode[] = [];
  readonly signupAccountExists: string[] = [];
  readonly testEmails: string[] = [];

  constructor(private readonly nodeEnv: 'development' | 'test' | 'production') {}

  async sendEmailVerification(input: EmailVerificationCodeMail): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('Email mock is not available in production');
    }
    this.sent.push(input);
    this.logger.log(`Email verification code mock to ${input.email} code=(redacted)`);
  }

  async sendPasswordResetCode(input: PasswordResetCodeMail): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('Email mock is not available in production');
    }
    this.passwordResets.push(input);
    this.logger.log(`Password reset code mock to ${input.email} code=(redacted)`);
  }

  async sendSignupCode(input: SignupCodeMail): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('Email mock is not available in production');
    }
    this.signupCodes.push(input);
    this.logger.log(`Signup code mock to ${input.email} code=(redacted)`);
  }

  async sendSignupAccountExists(input: { email: string }): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('Email mock is not available in production');
    }
    this.signupAccountExists.push(input.email);
    this.logger.log(`Signup account-exists notice mock to ${input.email}`);
  }

  async sendTestEmail(input: { email: string }): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('Email mock is not available in production');
    }
    this.testEmails.push(input.email);
    this.logger.log(`Test email mock to ${input.email}`);
  }

  readonly policyUpdates: PolicyUpdateMail[] = [];

  async sendPolicyUpdate(input: PolicyUpdateMail): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('Email mock is not available in production');
    }
    this.policyUpdates.push(input);
    const [local, domain] = input.email.split('@');
    this.logger.log(`Policy update mock (v${input.version}) to ${domain ? `${(local ?? '').slice(0, 2)}***@${domain}` : '***'}`);
  }
}

@Injectable()
export class UnavailableMailSender implements MailSender {
  async sendEmailVerification(): Promise<void> {
    throw new Error('Email provider is not configured');
  }

  async sendPasswordResetCode(): Promise<void> {
    throw new Error('Email provider is not configured');
  }

  async sendSignupCode(): Promise<void> {
    throw new Error('Email provider is not configured');
  }

  async sendSignupAccountExists(): Promise<void> {
    throw new Error('Email provider is not configured');
  }

  async sendTestEmail(): Promise<void> {
    throw new Error('Email provider is not configured');
  }

  async sendPolicyUpdate(): Promise<void> {
    throw new Error('Email provider is not configured');
  }
}
