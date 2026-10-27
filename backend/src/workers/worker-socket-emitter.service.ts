import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { RedisClientType } from 'redis';
import { Server } from 'socket.io';
import type { AppEnv } from '../platform/config/env.js';
import {
  attachRedisSocketAdapter,
  disconnectRedisClients,
} from '../modules/communication/realtime/redis-io-adapter.js';
import { SocketAccessService } from '../modules/communication/realtime/socket-access.service.js';
import { SnapshotFanoutService } from '../modules/communication/realtime/snapshot-fanout.service.js';

/**
 * The standalone worker runs the outbox relay but has no HTTP/Socket.IO server, so
 * SnapshotFanoutService stayed unbound and `snapshot` events never reached clients
 * (found by scripts/e2e-realtime-sim.ts, 2026-10-24). Bind a headless Server whose
 * Redis adapter publishes room broadcasts to the API nodes that hold the sockets.
 */
@Injectable()
export class WorkerSocketEmitter implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(WorkerSocketEmitter.name);
  private server: Server | null = null;
  private clients: RedisClientType[] = [];

  constructor(
    private readonly config: ConfigService<AppEnv, true>,
    private readonly fanout: SnapshotFanoutService,
    private readonly access: SocketAccessService,
  ) {}

  async onModuleInit(): Promise<void> {
    const nodeEnv = this.config.get('NODE_ENV', { infer: true });
    if (nodeEnv === 'test') {
      return;
    }
    const server = new Server();
    const result = await attachRedisSocketAdapter(server, this.config.get('REDIS_URL', { infer: true }), nodeEnv);
    this.clients = result.clients;
    if (result.mode !== 'redis') {
      // In-memory adapter cannot reach API sockets from another process.
      this.logger.warn({ msg: 'workers.socket_emitter_disabled', detail: 'Redis adapter unavailable' });
      await server.close();
      return;
    }
    this.server = server;
    this.fanout.bindServer(server);
    this.fanout.bindAccessCheck((userId, room) => this.access.canJoinRoom(userId, room));
    this.logger.log({ msg: 'workers.socket_emitter_bound', mode: result.mode });
  }

  async onModuleDestroy(): Promise<void> {
    await disconnectRedisClients(this.clients);
    this.clients = [];
    this.server = null;
  }
}
