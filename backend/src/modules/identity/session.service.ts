import { randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { authError } from './auth-error.js';
import { IDENTITY_REPOSITORY } from './identity.constants.js';
import {
  sessionChannel,
  storedChannel,
  type IdentityRepository,
  type UserRecord,
} from './identity.repository.js';
import {
  accessSecret,
  hashRefreshToken,
  randomSecret,
  signAccessToken,
  unixSeconds,
  type SessionChannelName,
} from '../../platform/security/token-crypto.js';

export type SessionResult = {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: {
    id: string;
    phone: string | null;
    email: string | null;
  };
};

@Injectable()
export class SessionService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  async issue(
    user: UserRecord,
    channel: SessionChannelName,
    device?: { deviceLabel?: string | null; userAgent?: string | null; ipAddress?: string | null },
  ): Promise<SessionResult> {
    if (user.deletedAt) {
      // S027 (DEC-PROD-037): a deleted account never gets a session again; during the grace
      // period only support/Admin can restore it.
      throw authError(403, 'ACCOUNT_DELETED', 'This account has been deleted');
    }
    const refreshToken = randomSecret();
    const now = new Date();
    const refreshTtl = this.config.get('JWT_REFRESH_TTL_SECONDS', { infer: true });
    const session = await this.repository.createSession({
      userId: user.id,
      familyId: randomUUID(),
      channel: storedChannel(channel),
      refreshTokenHash: hashRefreshToken(refreshToken),
      expiresAt: new Date(now.getTime() + refreshTtl * 1000),
      deviceLabel: device?.deviceLabel ?? null,
      userAgent: device?.userAgent ?? null,
      ipAddress: device?.ipAddress ?? null,
    });
    return this.toResult(user, session.id, channel, refreshToken, now);
  }

  async refresh(refreshToken: string): Promise<SessionResult> {
    const now = new Date();
    const refreshTtl = this.config.get('JWT_REFRESH_TTL_SECONDS', { infer: true });
    const nextRefreshToken = randomSecret();
    const result = await this.repository.rotateSession(
      hashRefreshToken(refreshToken),
      {
        refreshTokenHash: hashRefreshToken(nextRefreshToken),
        expiresAt: new Date(now.getTime() + refreshTtl * 1000),
      },
      now,
    );

    if (result.status === 'reuse') {
      // The token was already rotated. Reuse means it leaked or a client retried
      // after the successor was issued, so the whole family is revoked.
      throw authError(401, 'AUTH_REFRESH_REUSED', 'Refresh token reuse detected');
    }
    if (result.status !== 'rotated') {
      throw authError(401, 'AUTH_REFRESH_INVALID', 'Refresh token is invalid');
    }

    const user = await this.repository.findUserById(result.session.userId);
    if (!user || user.deletedAt) {
      throw authError(401, 'AUTH_REFRESH_INVALID', 'Refresh token is invalid');
    }
    await this.repository.touchSessionMeta(result.session.id, {}, now);
    return this.toResult(
      user,
      result.session.id,
      sessionChannel(result.session.channel),
      nextRefreshToken,
      now,
    );
  }

  async revoke(sessionId: string): Promise<{ revoked: true }> {
    await this.repository.revokeSession(sessionId, 'USER', new Date());
    return { revoked: true };
  }

  async revokeByRefreshToken(refreshToken: string): Promise<{ revoked: boolean }> {
    const hash = hashRefreshToken(refreshToken);
    const session = await this.repository.findSessionByRefreshTokenHash(hash);
    if (!session || session.revokedAt) {
      return { revoked: false };
    }
    await this.repository.revokeSession(session.id, 'USER', new Date());
    return { revoked: true };
  }

  private toResult(
    user: UserRecord,
    sessionId: string,
    channel: SessionChannelName,
    refreshToken: string,
    now: Date,
  ): SessionResult {
    const expiresIn = this.config.get('JWT_ACCESS_TTL_SECONDS', { infer: true });
    const issuedAt = unixSeconds(now);
    const secret = accessSecret({
      JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
    });
    return {
      accessToken: signAccessToken(
        {
          sub: user.id,
          sid: sessionId,
          ch: channel,
          iat: issuedAt,
          exp: issuedAt + expiresIn,
        },
        secret,
      ),
      refreshToken,
      expiresIn,
      user: {
        id: user.id,
        phone: user.phone,
        email: user.email,
      },
    };
  }
}
