import { Injectable, Logger } from '@nestjs/common';
import { redactPhone } from '../../modules/identity/phone-number.js';
import { SmsDeliveryError } from './sms-errors.js';


export interface SmsSender {
  sendOtp(phone: string, code: string): Promise<void>;
}

export type DeliveredOtp = {
  phone: string;
  code: string;
};

@Injectable()
export class MockSmsSender implements SmsSender {
  private readonly logger = new Logger(MockSmsSender.name);
  readonly sent: DeliveredOtp[] = [];

  constructor(private readonly nodeEnv: 'development' | 'test' | 'production') {}

  async sendOtp(phone: string, code: string): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('SMS mock is not available in production');
    }
    this.sent.push({ phone, code });
    if (this.nodeEnv === 'development' || this.nodeEnv === 'test') {
      // Prefix only: a full OTP in logs is a second copy of the secret.
      const codePrefix = code.slice(0, 2);
      this.logger.log(`SMS mock to ${redactPhone(phone)} code=${codePrefix}****`);
    }
  }
}

@Injectable()
export class UnavailableSmsSender implements SmsSender {
  async sendOtp(): Promise<void> {
    throw new SmsDeliveryError('not_configured', 'none');
  }
}
