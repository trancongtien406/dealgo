import { Injectable, Logger, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { PrismaService } from '../../platform/database/index.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { authError } from './auth-error.js';
import { normalizeEmail, normalizePhone, redactPhone } from './phone-number.js';

export type ReviewChannel = 'phone' | 'email';

/** Max fixed-code issues per rolling hour per process (on top of the per-route throttles). */
export const APP_REVIEW_MAX_CODES_PER_HOUR = 30;
const HOUR_MS = 3_600_000;

/**
 * App Store / Play review login (DEC-PROD-052). When APP_REVIEW_LOGIN_ENABLED is true in admin
 * settings, the configured review phone (APP_REVIEW_PHONE) and/or email (APP_REVIEW_EMAIL) receive
 * the fixed code from env APP_REVIEW_OTP_CODE instead of a random one, and no SMS/email is sent.
 * Off by default; every use is logged, every successful sign-in is written to ops_audit_logs.
 */
@Injectable()
export class AppReviewLoginService {
  private readonly logger = new Logger(AppReviewLoginService.name);
  private issued: number[] = [];

  constructor(
    private readonly config: ConfigService<AppEnv, true>,
    @Optional() private readonly settings?: PlatformSettingsService,
    @Optional() private readonly prisma?: PrismaService,
  ) {}

  /** Fixed code when `identifier` is the active review account for `channel`, else null. */
  async fixedCodeFor(channel: ReviewChannel, identifier: string): Promise<string | null> {
    if (!(await this.matches(channel, identifier))) {
      return null;
    }
    const code = this.config.get('APP_REVIEW_OTP_CODE', { infer: true });
    if (!code) {
      return null;
    }
    const now = Date.now();
    this.issued = this.issued.filter((at) => at > now - HOUR_MS);
    if (this.issued.length >= APP_REVIEW_MAX_CODES_PER_HOUR) {
      throw authError(429, 'AUTH_OTP_RATE_LIMITED', 'Too many verification codes');
    }
    this.issued.push(now);
    this.logger.warn({
      msg: 'auth.app_review.code_issued',
      channel,
      identifier: channel === 'phone' ? redactPhone(identifier) : identifier.replace(/^(.{2}).*@/, '$1***@'),
    });
    return code;
  }

  async matches(channel: ReviewChannel, identifier: string): Promise<boolean> {
    if (!this.settings || !this.config.get('APP_REVIEW_OTP_CODE', { infer: true })) {
      return false;
    }
    if (!(await this.settings.getBoolean('APP_REVIEW_LOGIN_ENABLED'))) {
      return false;
    }
    if (channel === 'phone') {
      const configured = normalizePhone((await this.settings.getString('APP_REVIEW_PHONE')).trim());
      return configured !== null && configured === normalizePhone(identifier);
    }
    const configured = (await this.settings.getString('APP_REVIEW_EMAIL')).trim();
    return configured !== '' && normalizeEmail(configured) === normalizeEmail(identifier);
  }

  /** Audit a session issued to the review account. Best-effort: never blocks the sign-in. */
  async recordSignIn(userId: string, channel: ReviewChannel): Promise<void> {
    this.logger.warn({ msg: 'auth.app_review.sign_in', channel, userId });
    const db = this.prisma?.db();
    if (!db) {
      return;
    }
    try {
      await db.opsAuditLog.create({
        data: {
          actorUserId: userId,
          action: 'APP_REVIEW_LOGIN',
          entityType: 'USER',
          entityId: userId,
          reason: `App review sign-in via fixed ${channel} code`,
          metadata: { channel },
        },
      });
    } catch (error) {
      this.logger.error(`App review audit write failed: ${(error as Error).message}`);
    }
  }
}
