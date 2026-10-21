import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import {
  InjectThrottlerOptions,
  InjectThrottlerStorage,
  ThrottlerGuard,
  type ThrottlerModuleOptions,
  type ThrottlerRequest,
  type ThrottlerStorage,
} from '@nestjs/throttler';
import type { AppEnv } from '../../platform/config/env.js';
import { normalizePhone } from './phone-number.js';

/**
 * Per-IP throttling alone lets rotating IPs SMS-bomb one number (and run up SMS cost).
 * This guard runs next to the IP throttler and caps OTP sends per normalized phone number:
 * `OTP_PHONE_LIMIT` (default 5) per `OTP_PHONE_WINDOW_MS` (default 15 min) — DEC-PROD-044.
 */
@Injectable()
export class PhoneOtpThrottlerGuard extends ThrottlerGuard {
  constructor(
    @InjectThrottlerOptions() options: ThrottlerModuleOptions,
    @InjectThrottlerStorage() storage: ThrottlerStorage,
    reflector: Reflector,
    private readonly config: ConfigService<AppEnv, true>,
  ) {
    super(options, storage, reflector);
  }

  protected override async getTracker(req: Record<string, unknown>): Promise<string> {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const raw = typeof body.phone === 'string' ? body.phone.slice(0, 32) : '';
    return `phone-otp:${normalizePhone(raw) ?? raw.replace(/\D/g, '')}`;
  }

  protected override handleRequest(requestProps: ThrottlerRequest): Promise<boolean> {
    return super.handleRequest({
      ...requestProps,
      limit: this.config.get('OTP_PHONE_LIMIT', { infer: true }),
      ttl: this.config.get('OTP_PHONE_WINDOW_MS', { infer: true }),
    });
  }
}
