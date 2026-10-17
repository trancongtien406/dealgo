import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
  createParamDecorator,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';
import type { AppEnv } from '../../platform/config/env.js';
import { authError } from './auth-error.js';
import { IDENTITY_REPOSITORY } from './identity.constants.js';
import { sessionChannel, type IdentityRepository } from './identity.repository.js';
import { accessSecret, verifyAccessToken, type SessionChannelName } from '../../platform/security/token-crypto.js';

export type RequestActor = {
  userId: string;
  sessionId: string;
  channel: SessionChannelName;
};

type AuthenticatedRequest = Request & { actor?: RequestActor };

export const CurrentActor = createParamDecorator(
  (_data: unknown, context: ExecutionContext): RequestActor => {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    if (!request.actor) {
      throw authError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    return request.actor;
  },
);

@Injectable()
export class AccessAuthGuard implements CanActivate {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    request.actor = await this.authenticate(request);
    return true;
  }

  private async authenticate(request: AuthenticatedRequest): Promise<RequestActor> {
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw authError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    const token = header.slice('Bearer '.length).trim();
    const secret = accessSecret({
      JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
    });
    const claims = verifyAccessToken(token, secret);
    if (!claims) {
      throw authError(401, 'UNAUTHORIZED', 'Authentication required');
    }

    const session = await this.repository.findSessionById(claims.sid);
    if (
      !session ||
      session.revokedAt ||
      session.userId !== claims.sub ||
      sessionChannel(session.channel) !== claims.ch ||
      session.expiresAt.getTime() <= Date.now()
    ) {
      throw authError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    return {
      userId: claims.sub,
      sessionId: claims.sid,
      channel: claims.ch,
    };
  }
}

@Injectable()
export class CustomerSessionGuard implements CanActivate {
  constructor(private readonly access: AccessAuthGuard) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    await this.access.canActivate(context);
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    if (request.actor?.channel !== 'customer') {
      throw authError(403, 'FORBIDDEN', 'A verified phone session is required');
    }
    return true;
  }
}

@Injectable()
export class OpsSessionGuard implements CanActivate {
  constructor(
    private readonly access: AccessAuthGuard,
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    await this.access.canActivate(context);
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    if (request.actor?.channel !== 'ops') {
      throw authError(403, 'FORBIDDEN', 'An operator session is required');
    }

    const grants = await this.repository.listGrants(request.actor.userId);
    const hasActiveOpsGrant = grants.some(
      (grant) => grant.role === 'OPS' && grant.status === 'ACTIVE',
    );
    if (!hasActiveOpsGrant) {
      throw authError(403, 'FORBIDDEN', 'An active operator role is required');
    }
    return true;
  }
}
