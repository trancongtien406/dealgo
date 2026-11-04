import { Injectable, Logger } from '@nestjs/common';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';

export type AppCheckVerificationResult = {
  allowed: boolean;
  valid: boolean;
  reason?: string;
};

@Injectable()
export class AppCheckService {
  private readonly logger = new Logger(AppCheckService.name);

  constructor(private readonly settings: PlatformSettingsService) {}

  async verifyToken(
    token: string | undefined,
    clientIp?: string | null,
    path?: string,
  ): Promise<AppCheckVerificationResult> {
    const mode = (await this.settings.getString('APP_CHECK_MODE').catch(() => 'OFF')).toUpperCase();

    if (mode === 'OFF') {
      return { allowed: true, valid: true };
    }

    const debugTokensRaw = await this.settings.getString('APP_CHECK_DEBUG_TOKENS').catch(() => '');
    const debugTokens = debugTokensRaw
      .split(',')
      .map((t) => t.trim())
      .filter(Boolean);

    if (token && debugTokens.includes(token)) {
      return { allowed: true, valid: true, reason: 'DEBUG_TOKEN' };
    }

    if (!token || token.trim().length === 0) {
      if (mode === 'AUDIT') {
        this.logger.warn(`[AppCheck AUDIT] Missing token from ${clientIp ?? 'unknown'} on ${path ?? ''}`);
        return { allowed: true, valid: false, reason: 'TOKEN_MISSING' };
      }
      return { allowed: false, valid: false, reason: 'TOKEN_MISSING' };
    }

    const parts = token.trim().split('.');
    if (parts.length !== 3) {
      if (mode === 'AUDIT') {
        this.logger.warn(`[AppCheck AUDIT] Malformed token from ${clientIp ?? 'unknown'} on ${path ?? ''}`);
        return { allowed: true, valid: false, reason: 'MALFORMED_JWT' };
      }
      return { allowed: false, valid: false, reason: 'MALFORMED_JWT' };
    }

    try {
      const payloadJson = Buffer.from(parts[1]!, 'base64url').toString('utf8');
      const payload = JSON.parse(payloadJson) as {
        exp?: number;
        iat?: number;
        sub?: string;
        iss?: string;
        aud?: string | string[];
      };

      const nowSec = Math.floor(Date.now() / 1000);
      if (typeof payload.exp === 'number' && payload.exp < nowSec) {
        if (mode === 'AUDIT') {
          this.logger.warn(`[AppCheck AUDIT] Expired token from ${clientIp ?? 'unknown'} on ${path ?? ''}`);
          return { allowed: true, valid: false, reason: 'TOKEN_EXPIRED' };
        }
        return { allowed: false, valid: false, reason: 'TOKEN_EXPIRED' };
      }

      const projectNumber = (await this.settings.getString('APP_CHECK_PROJECT_NUMBER').catch(() => '')).trim();
      if (projectNumber) {
        const expectedIss = `https://firebaseappcheck.googleapis.com/${projectNumber}`;
        if (payload.iss && payload.iss !== expectedIss) {
          if (mode === 'AUDIT') {
            this.logger.warn(`[AppCheck AUDIT] Invalid issuer from ${clientIp ?? 'unknown'}: ${payload.iss}`);
            return { allowed: true, valid: false, reason: 'INVALID_ISSUER' };
          }
          return { allowed: false, valid: false, reason: 'INVALID_ISSUER' };
        }
      }

      return { allowed: true, valid: true };
    } catch {
      if (mode === 'AUDIT') {
        this.logger.warn(`[AppCheck AUDIT] Invalid token parse from ${clientIp ?? 'unknown'} on ${path ?? ''}`);
        return { allowed: true, valid: false, reason: 'PARSE_FAILED' };
      }
      return { allowed: false, valid: false, reason: 'PARSE_FAILED' };
    }
  }
}
