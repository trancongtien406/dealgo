import { Inject, Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import { DATABASE_PING, type DatabasePing } from '../database/database-ping.js';
import { REDIS_PROBE, type RedisProbe } from './redis-ping.js';
import {
  WORKER_HEARTBEAT_NAME,
  WORKER_HEARTBEAT_STORE,
  outboxLagMs,
  workerStatus,
  type WorkerHeartbeatStore,
  type WorkerStatus,
} from './worker-heartbeat.js';

/** Background worker liveness + outbox lag (DEC-PROD-053). */
export type WorkerReport = {
  status: WorkerStatus;
  lastBeatAt: string | null;
  outboxLagMs: number | null;
  outboxLagAlertMs: number;
};

export type DependencyCheck = 'up' | 'down';

export type HealthReport = {
  status: 'ok' | 'degraded';
  checks: {
    database: DependencyCheck;
    redis: DependencyCheck;
  };
  worker?: WorkerReport;
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
  worker?: WorkerReport;
};

@Injectable()
export class HealthService {
  constructor(
    private readonly config: ConfigService<AppEnv, true>,
    @Inject(DATABASE_PING) private readonly database: DatabasePing,
    @Inject(REDIS_PROBE) private readonly redis: RedisProbe,
    @Optional() @Inject(WORKER_HEARTBEAT_STORE) private readonly heartbeats?: WorkerHeartbeatStore,
  ) {}

  /**
   * Worker heartbeat + outbox lag. `up` when the last beat is newer than WORKER_HEARTBEAT_STALE_MS.
   * Does not gate API readiness (a dead worker must not take the API out of rotation); it degrades
   * /health and /health/ready and makes /health/worker return 503 for the worker's own probe.
   */
  async worker(now = new Date()): Promise<WorkerReport | undefined> {
    if (!this.heartbeats) {
      return undefined;
    }
    const outboxLagAlertMs = this.config.get('OUTBOX_LAG_ALERT_MS', { infer: true });
    try {
      const [beat, oldest] = await Promise.all([
        this.heartbeats.latest(WORKER_HEARTBEAT_NAME),
        this.heartbeats.oldestPendingOutboxAt(),
      ]);
      return {
        status: workerStatus(beat, this.config.get('WORKER_HEARTBEAT_STALE_MS', { infer: true }), now),
        lastBeatAt: beat?.beatAt.toISOString() ?? null,
        outboxLagMs: outboxLagMs(oldest, now),
        outboxLagAlertMs,
      };
    } catch {
      return { status: 'unknown', lastBeatAt: null, outboxLagMs: null, outboxLagAlertMs };
    }
  }

  live(): LiveReport {
    return { status: 'ok' };
  }

  async check(): Promise<HealthReport> {
    const checks = await this.probeDependencies();
    const worker = checks.database === 'up' ? await this.worker() : undefined;
    return {
      status: checks.database === 'up' && checks.redis === 'up' && workerHealthy(worker) ? 'ok' : 'degraded',
      checks,
      ...(worker ? { worker } : {}),
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
    const worker = await this.worker();
    return {
      status: checks.redis === 'up' && workerHealthy(worker) ? 'ok' : 'degraded',
      checks,
      ...(worker ? { worker } : {}),
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

function workerHealthy(worker: WorkerReport | undefined): boolean {
  if (!worker) {
    return true;
  }
  return worker.status === 'up' && (worker.outboxLagMs ?? 0) <= worker.outboxLagAlertMs;
}
