import { Injectable, Logger } from '@nestjs/common';

export interface MailSender {
  sendEmailVerification(input: { email: string; verificationId: string; token: string }): Promise<void>;
  /** DEC-PROD-045: 6-digit forgot-password code (the old link token is retired). */
  sendPasswordResetCode(input: PasswordResetCodeMail): Promise<void>;
  /** `purpose: 'activation'` verifies the email of an existing, never-verified account. */
  sendSignupCode(input: SignupCodeMail): Promise<void>;
  /** Sent instead of a code when someone tries to sign up with an address that already has an account. */
  sendSignupAccountExists(input: { email: string }): Promise<void>;
}

export type DeliveredMail = {
  email: string;
  verificationId: string;
  token: string;
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
  readonly sent: DeliveredMail[] = [];
  readonly passwordResets: DeliveredPasswordReset[] = [];
  readonly signupCodes: DeliveredSignupCode[] = [];
  readonly signupAccountExists: string[] = [];

  constructor(private readonly nodeEnv: 'development' | 'test' | 'production') {}

  async sendEmailVerification(input: { email: string; verificationId: string; token: string }): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('Email mock is not available in production');
    }
    this.sent.push(input);
    this.logger.log(`Email mock to ${input.email} token=(redacted)`);
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
}
