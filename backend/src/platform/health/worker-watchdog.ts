import { Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import { OpsAlertService } from '../observability/ops-alert.js';
import { HealthService } from './health.service.js';

/**
 * API-side watchdog (DEC-PROD-053): the worker cannot report its own death, so the API checks the
 * heartbeat every WORKER_HEARTBEAT_STALE_MS and raises `worker.down` / `outbox.lag` through OpsAlertService.
 * Production only (in dev the worker is often not running). First check after one stale window.
 */
@Injectable()
export class WorkerWatchdog implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(WorkerWatchdog.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly health: HealthService,
    private readonly alerts: OpsAlertService,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  onModuleInit(): void {
    if (this.config.get('NODE_ENV', { infer: true }) !== 'production') {
      return;
    }
    const every = this.config.get('WORKER_HEARTBEAT_STALE_MS', { infer: true });
    this.timer = setInterval(() => void this.checkOnce().catch(() => undefined), every);
    this.timer.unref?.();
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  async checkOnce(now = new Date()): Promise<void> {
    const report = await this.health.worker(now);
    if (!report || report.status === 'unknown') {
      return;
    }
    await this.checkOutboxLag(report.outboxLagMs, report.outboxLagAlertMs, now);
    if (report.status === 'up') {
      this.alerts.resolve('worker.down');
      return;
    }
    this.logger.warn({ msg: 'workers.heartbeat_stale', status: report.status, lastBeatAt: report.lastBeatAt });
    await this.alerts.raise(
      {
        key: 'worker.down',
        severity: 'critical',
        summary: `Background worker ${report.status} (last beat ${report.lastBeatAt ?? 'never'})`,
        details: { ...report },
      },
      now.getTime(),
    );
  }

  private async checkOutboxLag(lagMs: number | null, alertMs: number, now: Date): Promise<void> {
    if (lagMs === null || lagMs <= alertMs) {
      this.alerts.resolve('outbox.lag');
      return;
    }
    this.logger.warn({ msg: 'outbox.lag_above_threshold', lagMs, alertMs });
    await this.alerts.raise(
      {
        key: 'outbox.lag',
        severity: 'warning',
        summary: `Outbox lag ${Math.round(lagMs / 1000)}s (threshold ${Math.round(alertMs / 1000)}s)`,
        details: { lagMs, alertMs },
      },
      now.getTime(),
    );
  }
}
