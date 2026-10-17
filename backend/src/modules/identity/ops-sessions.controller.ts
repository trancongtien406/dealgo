import { Body, Controller, Delete, Headers, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { OpsLoginDto } from './auth.dto.js';
import { accessSecret, verifyAccessToken } from '../../platform/security/token-crypto.js';
import { OpsAuthService } from './ops-auth.service.js';
import { SessionService } from './session.service.js';

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
  @ApiOperation({ summary: 'Ops email/password login' })
  login(@Body() body: OpsLoginDto) {
    return this.opsAuth.login(body.email, body.password);
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
