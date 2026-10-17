import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import { DATABASE_PING, type DatabasePing } from '../database/database-ping.js';
import { REDIS_PROBE, type RedisProbe } from './redis-ping.js';

export type DependencyCheck = 'up' | 'down';

export type HealthReport = {
  status: 'ok' | 'degraded';
  checks: {
    database: DependencyCheck;
    redis: DependencyCheck;
  };
};

export type LiveReport = {
  status: 'ok';
};

export type ReadyReport = {
  status: 'ok' | 'degraded' | 'not_ready';
  checks: {
    database: DependencyCheck;
    redis: DependencyCheck;
  };
};

@Injectable()
export class HealthService {
  constructor(
    private readonly config: ConfigService<AppEnv, true>,
    @Inject(DATABASE_PING) private readonly database: DatabasePing,
    @Inject(REDIS_PROBE) private readonly redis: RedisProbe,
  ) {}

  live(): LiveReport {
    return { status: 'ok' };
  }

  async check(): Promise<HealthReport> {
    const checks = await this.probeDependencies();
    return {
      status: checks.database === 'up' && checks.redis === 'up' ? 'ok' : 'degraded',
      checks,
    };
  }

  /**
   * Readiness: database is required (not_ready when down).
   * Redis remains optional and only degrades when down (same combined semantics as /health).
   */
  async checkReady(): Promise<ReadyReport> {
    const checks = await this.probeDependencies();
    if (checks.database === 'down') {
      return { status: 'not_ready', checks };
    }
    const nodeEnv = this.config.get('NODE_ENV', { infer: true });
    if (nodeEnv === 'production' && checks.redis === 'down') {
      return { status: 'not_ready', checks };
    }
    return {
      status: checks.redis === 'up' ? 'ok' : 'degraded',
      checks,
    };
  }

  private async probeDependencies(): Promise<{
    database: DependencyCheck;
    redis: DependencyCheck;
  }> {
    const redisUrl = this.config.get('REDIS_URL', { infer: true });
    const [databaseUp, redisUp] = await Promise.all([
      this.database.ping(),
      this.redis.ping(redisUrl),
    ]);
    return {
      database: databaseUp ? 'up' : 'down',
      redis: redisUp ? 'up' : 'down',
    };
  }
}
