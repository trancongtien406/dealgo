import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';

export type OpsAlert = {
  /** Stable key used for de-duplication, e.g. `outbox.lag`. */
  key: string;
  severity: 'warning' | 'critical';
  summary: string;
  details?: Record<string, unknown>;
};

/** Same alert key is re-sent at most once per window. */
export const OPS_ALERT_COOLDOWN_MS = 15 * 60_000;

/**
 * Alert hook (DEC-PROD-053). Always logs a structured `ops.alert` line (picked up by log-based
 * alerting / Sentry); when OPS_ALERT_WEBHOOK_URL is set it also POSTs JSON
 * `{ text, key, severity, summary, details, at }` — compatible with Slack/Discord/Google Chat
 * incoming webhooks (they read `text`) and generic receivers.
 */
@Injectable()
export class OpsAlertService {
  private readonly logger = new Logger(OpsAlertService.name);
  private readonly lastSent = new Map<string, number>();
  /** Overridable in tests. */
  fetchImpl: typeof fetch = (input, init) => fetch(input, init);

  constructor(private readonly config: ConfigService<AppEnv, true>) {}

  async raise(alert: OpsAlert, now = Date.now()): Promise<boolean> {
    const last = this.lastSent.get(alert.key);
    if (last !== undefined && now - last < OPS_ALERT_COOLDOWN_MS) {
      return false;
    }
    this.lastSent.set(alert.key, now);
    this.logger.error({ msg: 'ops.alert', ...alert });
    const url = this.config.get('OPS_ALERT_WEBHOOK_URL', { infer: true });
    if (!url) {
      return true;
    }
    try {
      const response = await this.fetchImpl(url, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          text: `[DealGo ${alert.severity}] ${alert.summary}`,
          ...alert,
          environment: this.config.get('NODE_ENV', { infer: true }),
          at: new Date(now).toISOString(),
        }),
        signal: AbortSignal.timeout(5_000),
      });
      if (!response.ok) {
        this.logger.warn({ msg: 'ops.alert.webhook_failed', status: response.status });
      }
    } catch (error) {
      this.logger.warn({ msg: 'ops.alert.webhook_failed', error: (error as Error).message });
    }
    return true;
  }

  /** Clears the cooldown so the next occurrence after recovery alerts again. */
  resolve(key: string): void {
    this.lastSent.delete(key);
  }
}
