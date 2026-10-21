import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/** Admin login attempts per email per window (DEC-PROD-044). */
export const OPS_LOGIN_LIMIT = 5;
export const OPS_LOGIN_WINDOW_MS = 5 * 60_000;

/**
 * Admin login goes through the website server, so every operator reaches the API from the same
 * IP. Throttling by IP would let one mistyped password burst lock everyone out; throttle by the
 * normalized email instead so a password guess on one account cannot be brute-forced.
 */
@Injectable()
export class OpsLoginThrottlerGuard extends ThrottlerGuard {
  protected override async getTracker(req: Record<string, unknown>): Promise<string> {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase().slice(0, 254) : '';
    return `ops-login:${email}`;
  }
}
