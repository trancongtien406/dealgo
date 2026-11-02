import { Logger } from '@nestjs/common';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient, type RedisClientType } from 'redis';
import type { Server } from 'socket.io';

/**
 * REL-002: true once this process wanted the Redis adapter (REDIS_URL set) but fell back to the
 * in-memory adapter. Rooms are then process-local, so production readiness reports not_ready.
 */
let redisAdapterFallback = false;

export function realtimeAdapterFellBack(): boolean {
  return redisAdapterFallback;
}

/** Test hook. */
export function resetRealtimeAdapterState(): void {
  redisAdapterFallback = false;
}

/**
 * Attaches @socket.io/redis-adapter when REDIS_URL is reachable.
 * Soft-falls back to the default in-memory adapter when Redis is down (non-prod).
 * Production logs an error and /health/ready returns not_ready (REL-002) so the instance leaves
 * rotation instead of silently splitting socket rooms across nodes.
 */
export async function attachRedisSocketAdapter(
  server: Server,
  redisUrl: string | undefined,
  nodeEnv: string,
): Promise<{ mode: 'redis' | 'memory'; clients: RedisClientType[] }> {
  const logger = new Logger('RedisIoAdapter');
  if (!redisUrl) {
    logger.log({ msg: 'realtime.adapter', mode: 'memory', detail: 'REDIS_URL unset' });
    return { mode: 'memory', clients: [] };
  }

  const pubClient: RedisClientType = createClient({ url: redisUrl });
  const subClient: RedisClientType = pubClient.duplicate();
  pubClient.on('error', (error: Error) => {
    logger.warn({ msg: 'realtime.redis_pub_error', error: error.message });
  });
  subClient.on('error', (error: Error) => {
    logger.warn({ msg: 'realtime.redis_sub_error', error: error.message });
  });

  try {
    await Promise.all([pubClient.connect(), subClient.connect()]);
    server.adapter(createAdapter(pubClient, subClient));
    redisAdapterFallback = false;
    logger.log({ msg: 'realtime.adapter', mode: 'redis' });
    return { mode: 'redis', clients: [pubClient, subClient] };
  } catch (error) {
    await safeQuit(pubClient);
    await safeQuit(subClient);
    const detail = error instanceof Error ? error.message : 'unknown';
    redisAdapterFallback = true;
    if (nodeEnv === 'production') {
      logger.error({
        msg: 'realtime.adapter',
        mode: 'memory',
        detail: `Redis adapter failed in production; single-process rooms only: ${detail}`,
      });
    } else {
      logger.warn({
        msg: 'realtime.adapter',
        mode: 'memory',
        detail: `Redis unreachable; soft fallback: ${detail}`,
      });
    }
    return { mode: 'memory', clients: [] };
  }
}

export async function disconnectRedisClients(clients: RedisClientType[]): Promise<void> {
  await Promise.all(clients.map((client) => safeQuit(client)));
}

async function safeQuit(client: RedisClientType): Promise<void> {
  try {
    if (client.isOpen) {
      await client.quit();
    }
  } catch {
    try {
      client.destroy();
    } catch {
      // ignore
    }
  }
}
