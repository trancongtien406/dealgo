import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Socket } from 'socket.io';
import type { AppEnv } from '../../../platform/config/env.js';
import type { RequestActor } from '../../identity/access-auth.guard.js';
import { IDENTITY_REPOSITORY } from '../../identity/identity.constants.js';
import { sessionChannel, type IdentityRepository } from '../../identity/identity.repository.js';
import { accessSecret, verifyAccessToken } from '../../../platform/security/token-crypto.js';
import { FoodService } from '../../food-order/food.service.js';
import { RideService } from '../../ride/ride.service.js';
import type { ParsedSnapshotRoom } from './realtime.constants.js';

@Injectable()
export class SocketAccessService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly rides: RideService,
    private readonly food: FoodService,
  ) {}

  async authenticateSocket(client: Socket): Promise<RequestActor> {
    const token = extractAccessToken(client);
    if (!token) {
      throw new SocketAuthError('UNAUTHORIZED', 'Authentication required');
    }
    const secret = accessSecret({
      JWT_ACCESS_SECRET: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      NODE_ENV: this.config.get('NODE_ENV', { infer: true }),
    });
    const claims = verifyAccessToken(token, secret);
    if (!claims) {
      throw new SocketAuthError('UNAUTHORIZED', 'Authentication required');
    }
    const session = await this.identity.findSessionById(claims.sid);
    if (
      !session ||
      session.revokedAt ||
      session.userId !== claims.sub ||
      sessionChannel(session.channel) !== claims.ch ||
      session.expiresAt.getTime() <= Date.now()
    ) {
      throw new SocketAuthError('UNAUTHORIZED', 'Authentication required');
    }

    if (claims.ch === 'ops') {
      const grants = await this.identity.listGrants(claims.sub);
      const hasActiveOpsGrant = grants.some(
        (grant) => grant.role === 'OPS' && grant.status === 'ACTIVE',
      );
      if (!hasActiveOpsGrant) {
        throw new SocketAuthError('FORBIDDEN', 'An active operator role is required');
      }
    }

    return {
      userId: claims.sub,
      sessionId: claims.sid,
      channel: claims.ch,
    };
  }

  async verifyActiveActor(actor: RequestActor): Promise<boolean> {
    const session = await this.identity.findSessionById(actor.sessionId);
    if (
      !session ||
      session.revokedAt ||
      session.userId !== actor.userId ||
      sessionChannel(session.channel) !== actor.channel ||
      session.expiresAt.getTime() <= Date.now()
    ) {
      return false;
    }

    if (actor.channel === 'ops') {
      const grants = await this.identity.listGrants(actor.userId);
      return grants.some((grant) => grant.role === 'OPS' && grant.status === 'ACTIVE');
    }

    return true;
  }

  async canJoinRoom(userId: string, room: ParsedSnapshotRoom): Promise<boolean> {
    if (room.kind === 'ride') {
      return this.rides.canSubscribe(userId, room.id);
    }
    if (room.kind === 'store') {
      return this.food.canSubscribeStore(userId, room.id);
    }
    return this.food.canSubscribe(userId, room.id);
  }
}

export class SocketAuthError extends Error {
  constructor(
    readonly code: 'UNAUTHORIZED' | 'FORBIDDEN' | 'INVALID_ROOM',
    message: string,
  ) {
    super(message);
    this.name = 'SocketAuthError';
  }
}

export function extractAccessToken(client: Socket): string | null {
  const auth = client.handshake.auth as Record<string, unknown> | undefined;
  const fromAuthToken = asBearer(auth?.token);
  if (fromAuthToken) {
    return fromAuthToken;
  }
  const fromAuthHeader = asBearer(auth?.authorization);
  if (fromAuthHeader) {
    return fromAuthHeader;
  }
  const header = client.handshake.headers.authorization;
  return asBearer(header);
}

function asBearer(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  if (trimmed.toLowerCase().startsWith('bearer ')) {
    const token = trimmed.slice('Bearer '.length).trim();
    return token || null;
  }
  return trimmed;
}
