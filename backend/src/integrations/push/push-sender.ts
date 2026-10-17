import { Injectable, Logger } from '@nestjs/common';

export type PushNotification = {
  userId: string;
  title: string;
  body: string;
  data: Record<string, string>;
};

export interface PushSender {
  send(notification: PushNotification): Promise<void>;
}

export type DeliveredPush = PushNotification;

function redactUserId(userId: string): string {
  if (userId.length <= 8) {
    return '********';
  }
  return `${userId.slice(0, 4)}…${userId.slice(-4)}`;
}

@Injectable()
export class MockPushSender implements PushSender {
  private readonly logger = new Logger(MockPushSender.name);
  readonly sent: DeliveredPush[] = [];

  constructor(private readonly nodeEnv: 'development' | 'test' | 'production') {}

  async send(notification: PushNotification): Promise<void> {
    if (this.nodeEnv === 'production') {
      throw new Error('Push mock is not available in production');
    }
    this.sent.push(notification);
    this.logger.log(
      `Push mock user=${redactUserId(notification.userId)} title=${notification.title} dataKeys=${Object.keys(notification.data).join(',')}`,
    );
  }
}

@Injectable()
export class UnavailablePushSender implements PushSender {
  async send(): Promise<void> {
    throw new Error('Push provider is not configured');
  }
}
