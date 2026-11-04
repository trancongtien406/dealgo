import { Logger } from '@nestjs/common';
import type { IntegrationSettingsService } from '../../platform/integration-settings/integration-settings.service.js';
import { EsmsSmsSender } from './esms-sms-sender.js';
import { isSmsSenderAvailable, type SmsEnv } from './sms-factory.js';
import { MockSmsSender, UnavailableSmsSender, type SmsSender } from './sms-sender.js';
import { SpeedSmsSender } from './speedsms-sms-sender.js';

export class DynamicSmsSender implements SmsSender {
  private readonly logger = new Logger(DynamicSmsSender.name);

  constructor(
    private readonly envSender: SmsSender,
    private readonly env: SmsEnv,
    private readonly ttlMinutes: number,
    private readonly settings?: IntegrationSettingsService,
  ) {}

  async isConfigured(): Promise<boolean> {
    const sender = await this.resolveSender();
    return isSmsSenderAvailable(sender);
  }

  private async resolveSender(): Promise<SmsSender> {
    if (!this.settings) {
      return this.envSender;
    }

    try {
      const values = await this.settings.values('SMS');
      const provider = values.config.provider?.trim().toLowerCase();
      if (!provider) {
        return this.envSender;
      }

      if (provider === 'none') {
        return new UnavailableSmsSender();
      }

      if (provider === 'mock') {
        return new MockSmsSender(this.env.NODE_ENV);
      }

      const common = {
        template: values.config.template || this.env.SMS_OTP_TEMPLATE,
        ttlMinutes: this.ttlMinutes,
        timeoutMs: this.env.SMS_HTTP_TIMEOUT_MS,
        maxAttempts: this.env.SMS_HTTP_MAX_ATTEMPTS,
      };

      if (provider === 'esms') {
        const apiKey = values.secrets.apiKey?.trim() || this.env.ESMS_API_KEY;
        const secretKey = values.secrets.secretKey?.trim() || this.env.ESMS_SECRET_KEY;
        const brandname = values.config.brandname?.trim() || this.env.ESMS_BRANDNAME;

        if (apiKey && secretKey && brandname) {
          return new EsmsSmsSender({
            ...common,
            apiKey,
            secretKey,
            brandname,
            smsType: values.config.smsType || this.env.ESMS_SMS_TYPE,
            sandbox: values.config.sandbox === 'true' || (this.env.NODE_ENV !== 'production' && this.env.ESMS_SANDBOX === true),
            baseUrl: values.config.baseUrl || this.env.ESMS_BASE_URL,
          });
        }
        return new UnavailableSmsSender();
      }

      if (provider === 'speedsms') {
        const accessToken = values.secrets.accessToken?.trim() || this.env.SPEEDSMS_ACCESS_TOKEN;
        if (accessToken) {
          return new SpeedSmsSender({
            ...common,
            accessToken,
            sender: values.config.sender || this.env.SPEEDSMS_SENDER,
            smsType: values.config.smsType || this.env.SPEEDSMS_SMS_TYPE,
            baseUrl: values.config.baseUrl || this.env.SPEEDSMS_BASE_URL,
          });
        }
        return new UnavailableSmsSender();
      }
    } catch (err) {
      this.logger.warn(`Could not resolve SMS sender from integration settings: ${err}`);
    }

    return this.envSender;
  }

  async sendOtp(phone: string, code: string): Promise<void> {
    const sender = await this.resolveSender();
    return sender.sendOtp(phone, code);
  }
}
