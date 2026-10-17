import { Injectable, Logger } from '@nestjs/common';

export interface MailSender {
  sendEmailVerification(input: { email: string; verificationId: string; token: string }): Promise<void>;
}

export type DeliveredMail = {
  email: string;
  verificationId: string;
  token: string;
};

@Injectable()
export class MockMailSender implements MailSender {
  private readonly logger = new Logger(MockMailSender.name);
  readonly sent: DeliveredMail[] = [];

  constructor(private readonly nodeEnv: 'development' | 'test' | 'production') {}

  async sendEmailVerification(input: { email: string; verificationId: string; token: string }): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('Email mock is not available in production');
    }
    this.sent.push(input);
    this.logger.log(`Email mock to ${input.email} token=(redacted)`);
  }
}

@Injectable()
export class UnavailableMailSender implements MailSender {
  async sendEmailVerification(): Promise<void> {
    throw new Error('Email provider is not configured');
  }
}
