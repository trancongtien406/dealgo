import { Body, Controller, Delete, Headers, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { ClientIp } from '../../platform/http/client-ip.decorator.js';
import { OpsLoginDto } from './auth.dto.js';
import { accessSecret, verifyAccessToken } from '../../platform/security/token-crypto.js';
import { OpsAuthService } from './ops-auth.service.js';
import { SessionService } from './session.service.js';
import { OPS_LOGIN_LIMIT, OPS_LOGIN_WINDOW_MS, OpsLoginThrottlerGuard } from './ops-login-throttler.guard.js';

@ApiTags('identity')
@Controller('v1/ops')
export class OpsSessionsController {
  constructor(
    private readonly opsAuth: OpsAuthService,
    private readonly sessions: SessionService,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  @Post('sessions')
  @HttpCode(HttpStatus.OK)
  @UseGuards(OpsLoginThrottlerGuard)
  @Throttle({ default: { limit: OPS_LOGIN_LIMIT, ttl: OPS_LOGIN_WINDOW_MS } })
  @ApiOperation({ summary: 'Ops email/password login (5 attempts per email per 5 minutes)' })
  login(
    @Body() body: OpsLoginDto,
    @ClientIp() ip?: string | null,
    @Headers('user-agent') userAgent?: string,
    @Headers('x-device-id') deviceId?: string,
  ) {
    return this.opsAuth.login(body.email, body.password, {
      deviceId: deviceId?.trim() || null,
      userAgent: userAgent ?? null,
      ipAddress: ip ?? null,
    });
  }

  @Delete('sessions')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Ops logout and revoke session/refresh token' })
  async logout(
    @Headers('authorization') authHeader?: string,
    @Body() body?: { refreshToken?: string },
  ) {
    let revoked = false;
    if (body?.refreshToken) {
      const res = await this.sessions.revokeByRefreshToken(body.refreshToken);
      if (res.revoked) revoked = true;
    }
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice('Bearer '.length).trim();
      const secret = accessSecret({
        JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
        NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
      });
      const claims = verifyAccessToken(token, secret);
      if (claims?.sid) {
        await this.sessions.revoke(claims.sid);
        revoked = true;
      }
    }
    return { success: true, revoked };
  }
}
