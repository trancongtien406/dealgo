import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/** Views per share link per minute: family on one trip polling every 15 s fits with room to spare. */
export const RIDE_SHARE_VIEW_LIMIT_PER_MIN = 30;

/**
 * The share page is rendered by the website server, so every viewer reaches the API from the
 * same IP. Throttling by IP would let a few viewers (or one OTP burst) lock out everyone, so the
 * public view is throttled per token instead.
 */
@Injectable()
export class ShareViewThrottlerGuard extends ThrottlerGuard {
  protected override async getTracker(req: Record<string, unknown>): Promise<string> {
    const params = (req.params ?? {}) as Record<string, unknown>;
    const token = typeof params.token === 'string' ? params.token.slice(0, 64) : '';
    return `ride-share:${token}`;
  }
}
