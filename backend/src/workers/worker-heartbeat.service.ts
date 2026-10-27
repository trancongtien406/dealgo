import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { hostname } from 'node:os';
import type { AppEnv } from '../platform/config/env.js';
import {
  WORKER_HEARTBEAT_NAME,
  WORKER_HEARTBEAT_STORE,
  outboxLagMs,
  type WorkerHeartbeatStore,
} from '../platform/health/worker-heartbeat.js';
import { OpsAlertService } from '../platform/observability/ops-alert.js';

/**
 * Worker liveness + outbox lag (DEC-PROD-053). Each tick upserts worker_heartbeats (read by the
 * API's /health endpoints and watchdog) and logs the `outbox_lag_ms` metric; lag above
 * OUTBOX_LAG_ALERT_MS raises an ops alert.
 */
@Injectable()
export class WorkerHeartbeatService {
  private readonly logger = new Logger(WorkerHeartbeatService.name);
  private readonly startedAt = new Date();
  private readonly instance = `${hostname()}:${process.pid}`;

  constructor(
    @Inject(WORKER_HEARTBEAT_STORE) private readonly store: WorkerHeartbeatStore,
    private readonly alerts: OpsAlertService,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  async runOnce(now = new Date()): Promise<{ outboxLagMs: number }> {
    const lag = outboxLagMs(await this.store.oldestPendingOutboxAt(), now);
    await this.store.beat(
      { name: WORKER_HEARTBEAT_NAME, instance: this.instance, startedAt: this.startedAt, meta: { outboxLagMs: lag } },
      now,
    );
    const threshold = this.config.get('OUTBOX_LAG_ALERT_MS', { infer: true });
    if (lag > threshold) {
      this.logger.warn({ msg: 'metric', metric: 'outbox_lag_ms', value: lag, threshold });
      await this.alerts.raise(
        {
          key: 'outbox.lag',
          severity: 'critical',
          summary: `Outbox lag ${Math.round(lag / 1000)}s exceeds ${Math.round(threshold / 1000)}s`,
          details: { outboxLagMs: lag, thresholdMs: threshold },
        },
        now.getTime(),
      );
    } else {
      this.logger.debug({ msg: 'metric', metric: 'outbox_lag_ms', value: lag });
      this.alerts.resolve('outbox.lag');
    }
    return { outboxLagMs: lag };
  }
}
