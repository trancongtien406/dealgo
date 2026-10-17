import { Injectable, Logger, type OnModuleDestroy } from '@nestjs/common';
import type { ThrottlerStorage } from '@nestjs/throttler';
import { createClient, type RedisClientType } from 'redis';

type ThrottleHit = {
  totalHits: number;
  timeToExpire: number;
  isBlocked: boolean;
  timeToBlockExpire: number;
};

/**
 * Multi-instance OTP throttle storage backed by Redis INCR + PEXPIRE.
 * Used when REDIS_URL is set; otherwise ThrottlerModule keeps in-memory storage.
 */
@Injectable()
export class RedisThrottlerStorage implements ThrottlerStorage, OnModuleDestroy {
  private readonly logger = new Logger(RedisThrottlerStorage.name);
  private client: RedisClientType | null = null;
  private connectPromise: Promise<RedisClientType | null> | null = null;
  private readonly localHits = new Map<string, { count: number; expiresAt: number }>();

  constructor(private readonly redisUrl: string) {}

  async increment(
    key: string,
    ttl: number,
    limit: number,
    _blockDuration: number,
    throttlerName: string,
  ): Promise<ThrottleHit> {
    const redisKey = `throttler:${throttlerName}:${key}`;
    try {
      const client = await this.ensureClient();
      if (!client) {
        return this.incrementLocal(redisKey, ttl, limit);
      }

      const totalHits = await client.incr(redisKey);
      if (totalHits === 1) {
        await client.pExpire(redisKey, ttl);
      }
      const pttl = await client.pTTL(redisKey);
      const timeToExpire = Math.max(1, Math.ceil(Math.max(pttl, 0) / 1000));
      const isBlocked = totalHits > limit;
      return {
        totalHits,
        timeToExpire,
        isBlocked,
        timeToBlockExpire: isBlocked ? timeToExpire : 0,
      };
    } catch (error) {
      this.logger.warn({
        msg: 'throttler.redis_error_fallback_local',
        detail: error instanceof Error ? error.message : 'redis command failed',
      });
      return this.incrementLocal(redisKey, ttl, limit);
    }
  }

  private incrementLocal(redisKey: string, ttl: number, limit: number): ThrottleHit {
    const now = Date.now();
    if (this.localHits.size > 2000) {
      for (const [k, v] of this.localHits.entries()) {
        if (v.expiresAt <= now) {
          this.localHits.delete(k);
        }
      }
    }

    const entry = this.localHits.get(redisKey);
    if (!entry || entry.expiresAt <= now) {
      this.localHits.set(redisKey, { count: 1, expiresAt: now + ttl });
      return {
        totalHits: 1,
        timeToExpire: Math.ceil(ttl / 1000),
        isBlocked: false,
        timeToBlockExpire: 0,
      };
    }

    entry.count += 1;
    const timeToExpire = Math.max(1, Math.ceil((entry.expiresAt - now) / 1000));
    const isBlocked = entry.count > limit;
    return {
      totalHits: entry.count,
      timeToExpire,
      isBlocked,
      timeToBlockExpire: isBlocked ? timeToExpire : 0,
    };
  }

  async onModuleDestroy(): Promise<void> {
    if (this.client?.isOpen) {
      await this.client.quit().catch(() => undefined);
    }
    this.client = null;
    this.connectPromise = null;
  }

  private ensureClient(): Promise<RedisClientType | null> {
    if (this.client?.isOpen) {
      return Promise.resolve(this.client);
    }
    if (!this.connectPromise) {
      this.connectPromise = this.connect();
    }
    return this.connectPromise;
  }

  private async connect(): Promise<RedisClientType | null> {
    try {
      const client = createClient({
        url: this.redisUrl,
        socket: {
          connectTimeout: 500,
          reconnectStrategy: false,
        },
      }) as RedisClientType;
      client.on('error', (error: Error) => {
        this.logger.warn(`Redis throttler client error: ${error.message}`);
      });
      await client.connect();
      this.client = client;
      this.logger.log({ msg: 'throttler.storage', mode: 'redis' });
      return client;
    } catch (error) {
      this.logger.warn({
        msg: 'throttler.storage',
        mode: 'degraded',
        detail: error instanceof Error ? error.message : 'connect failed',
      });
      this.connectPromise = null;
      return null;
    }
  }
}
