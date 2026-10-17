import { Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { RedisClientType } from 'redis';
import type { Server, Socket } from 'socket.io';
import type { AppEnv } from '../../../platform/config/env.js';
import { resolveAllowedOrigins } from '../../../platform/http/local-dev-cors.js';
import {
  parseSnapshotRoom,
  SUBSCRIBE_EVENT,
  UNSUBSCRIBE_EVENT,
} from './realtime.constants.js';
import { attachRedisSocketAdapter, disconnectRedisClients } from './redis-io-adapter.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';
import { SocketAccessService, SocketAuthError } from './socket-access.service.js';

type ActorSocket = Socket & {
  data: {
    actor?: {
      userId: string;
      sessionId: string;
      channel: string;
    };
  };
};

@WebSocketGateway({
  cors: {
    origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
      if (!origin) {
        callback(null, true);
        return;
      }
      const allowed = resolveAllowedOrigins({
        CORS_ALLOWED_ORIGINS: process.env.CORS_ALLOWED_ORIGINS,
        NODE_ENV: process.env.NODE_ENV,
      });
      if (allowed.includes(origin)) {
        callback(null, true);
      } else {
        callback(null, false);
      }
    },
    credentials: true,
  },
})
export class SnapshotGateway implements OnGatewayInit, OnGatewayConnection, OnModuleDestroy {
  private readonly logger = new Logger(SnapshotGateway.name);
  private redisClients: RedisClientType[] = [];
  private sessionAuditTimer: NodeJS.Timeout | null = null;

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly access: SocketAccessService,
    private readonly fanout: SnapshotFanoutService,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  afterInit(server: Server): void {
    this.fanout.bindServer(server);
    void this.attachAdapter(server);
    this.sessionAuditTimer = setInterval(async () => {
      try {
        const sockets = await server.fetchSockets();
        for (const s of sockets) {
          const actor = (s.data as { actor?: { userId: string; sessionId: string; channel: string } }).actor;
          if (actor) {
            const active = await this.access.verifyActiveActor(actor as never);
            if (!active) {
              s.emit('error', { code: 'UNAUTHORIZED', message: 'Session revoked or expired' });
              s.disconnect(true);
            }
          }
        }
      } catch {
        // best-effort background audit
      }
    }, 30_000);
    this.sessionAuditTimer.unref?.();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sessionAuditTimer) {
      clearInterval(this.sessionAuditTimer);
      this.sessionAuditTimer = null;
    }
    await disconnectRedisClients(this.redisClients);
    this.redisClients = [];
  }

  async handleConnection(client: ActorSocket): Promise<void> {
    try {
      const actor = await this.access.authenticateSocket(client);
      client.data.actor = actor;
    } catch (error) {
      const code = error instanceof SocketAuthError ? error.code : 'UNAUTHORIZED';
      client.emit('error', { code, message: 'Authentication required' });
      client.disconnect(true);
    }
  }

  @SubscribeMessage(SUBSCRIBE_EVENT)
  async subscribe(
    @ConnectedSocket() client: ActorSocket,
    @MessageBody() body: { room?: string },
  ): Promise<{ ok: true; room: string } | { ok: false; code: string }> {
    const actor = client.data.actor;
    if (!actor) {
      return { ok: false, code: 'UNAUTHORIZED' };
    }
    const isStillActive = await this.access.verifyActiveActor(actor as never);
    if (!isStillActive) {
      client.emit('error', { code: 'UNAUTHORIZED', message: 'Session revoked or expired' });
      client.disconnect(true);
      return { ok: false, code: 'UNAUTHORIZED' };
    }
    const parsed = parseSnapshotRoom(body?.room);
    if (!parsed) {
      return { ok: false, code: 'INVALID_ROOM' };
    }
    const allowed = await this.access.canJoinRoom(actor.userId, parsed);
    if (!allowed) {
      this.logger.debug({
        msg: 'realtime.subscribe_denied',
        userId: actor.userId,
        room: parsed.room,
      });
      return { ok: false, code: 'FORBIDDEN' };
    }
    await client.join(parsed.room);
    return { ok: true, room: parsed.room };
  }

  @SubscribeMessage(UNSUBSCRIBE_EVENT)
  async unsubscribe(
    @ConnectedSocket() client: ActorSocket,
    @MessageBody() body: { room?: string },
  ): Promise<{ ok: true; room: string } | { ok: false; code: string }> {
    const parsed = parseSnapshotRoom(body?.room);
    if (!parsed) {
      return { ok: false, code: 'INVALID_ROOM' };
    }
    await client.leave(parsed.room);
    return { ok: true, room: parsed.room };
  }

  private async attachAdapter(server: Server): Promise<void> {
    const result = await attachRedisSocketAdapter(
      server,
      this.config.get('REDIS_URL', { infer: true }),
      this.config.get('NODE_ENV', { infer: true }),
    );
    this.redisClients = result.clients;
  }
}
