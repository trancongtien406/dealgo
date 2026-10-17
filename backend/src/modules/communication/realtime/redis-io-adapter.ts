import { Logger } from '@nestjs/common';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient, type RedisClientType } from 'redis';
import type { Server } from 'socket.io';

/**
 * Attaches @socket.io/redis-adapter when REDIS_URL is reachable.
 * Soft-falls back to the default in-memory adapter when Redis is down (non-prod).
 * Production logs an error but still boots single-process so HTTP stays available.
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
    logger.log({ msg: 'realtime.adapter', mode: 'redis' });
    return { mode: 'redis', clients: [pubClient, subClient] };
  } catch (error) {
    await safeQuit(pubClient);
    await safeQuit(subClient);
    const detail = error instanceof Error ? error.message : 'unknown';
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
