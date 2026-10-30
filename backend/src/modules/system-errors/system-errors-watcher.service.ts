import { Injectable, Logger, OnModuleDestroy, OnModuleInit, Optional } from '@nestjs/common';
import { OpsEventBus } from '../../platform/ops-events/ops-event-bus.js';
import { SystemErrorsService } from './system-errors.service.js';

/** How often the API asks Sentry for the unresolved count while an admin stream is open. */
export const SYSTEM_ERRORS_WATCH_MS = 120_000;

/**
 * Sentry has no push to DealGo without a webhook (which needs a Sentry integration
 * client secret: OPEN). Until then the API, not each browser, checks the unresolved
 * count, only while at least one admin SSE stream is open, and emits `systemErrors`
 * only when the count changes.
 */
@Injectable()
export class SystemErrorsWatcherService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(SystemErrorsWatcherService.name);
  private timer: ReturnType<typeof setInterval> | null = null;
  private offCount: (() => void) | null = null;
  private last: number | null | undefined = undefined;

  constructor(
    private readonly errors: SystemErrorsService,
    @Optional() private readonly bus?: OpsEventBus,
    @Optional() private readonly intervalMs: number = SYSTEM_ERRORS_WATCH_MS,
  ) {}

  onModuleInit(): void {
    if (!this.bus) return;
    this.offCount = this.bus.onSubscriberCount((n) => this.sync(n));
    this.sync(this.bus.subscriberCount);
  }

  onModuleDestroy(): void {
    this.offCount?.();
    this.offCount = null;
    this.stop();
  }

  get running(): boolean {
    return this.timer !== null;
  }

  private sync(subscribers: number): void {
    if (subscribers > 0 && !this.timer) {
      this.timer = setInterval(() => void this.check(), this.intervalMs);
      this.timer.unref?.();
      void this.check();
    } else if (subscribers === 0) {
      this.stop();
    }
  }

  private stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    this.last = undefined;
  }

  async check(): Promise<void> {
    try {
      const { count } = await this.errors.unresolvedCount();
      if (this.last !== undefined && count !== this.last) {
        this.bus?.publish({ type: 'systemErrors', reason: 'countChanged', count, at: new Date().toISOString() });
      }
      this.last = count;
    } catch (error) {
      this.logger.debug({ msg: 'system_errors.watch_failed', error: (error as Error).message });
    }
  }
}
