import { Injectable, Logger } from '@nestjs/common';
import type { NewJobAlert } from './new-job-sound.js';

export type PushNotification = {
  userId: string;
  title: string;
  body: string;
  data: Record<string, string>;
  /**
   * Replace-not-stack key (Android collapse_key + notification tag, iOS
   * apns-collapse-id) so a re-broadcast of the same ride request updates one notification.
   */
  collapseKey?: string;
  /** Drop the push if it cannot be delivered within this many seconds. */
  ttlSeconds?: number;
  /** Time-sensitive (new ride request) → Android high priority / iOS priority 10. */
  urgent?: boolean;
  /**
   * New ride / food job / merchant order: plays the spoken DealGo sound (iOS aps.sound +
   * Android channel) or, when customSound is false, the default sound on a high channel.
   */
  alert?: NewJobAlert;
  /**
   * FCM tokens registered under these platforms are skipped. An incoming call that
   * already rang CallKit through PushKit skips `ios`, so the iPhone rings once (no second
   * "đang gọi" banner).
   */
  skipPlatforms?: readonly string[];
  /**
   * Incoming call: Android gets a data-only message (title/body ride in data) so the app's
   * background handler shows only the native full-screen call UI, never a second FCM tray
   * notification beside it. iOS keeps a visible alert (aps.alert) and web a webpush card.
   */
  androidDataOnly?: boolean;
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

  constructor(
    private readonly nodeEnv: 'development' | 'test' | 'production',
  ) {}

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
