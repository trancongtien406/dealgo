import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Queue, Worker } from 'bullmq';
import type { AppEnv } from '../platform/config/env.js';
import { OutboxRelayService } from '../modules/communication/outbox/outbox-relay.service.js';
import { RideExpiryService } from './ride-expiry.service.js';

const RIDE_EXPIRY_JOB = 'ride-expiry';
const OUTBOX_RELAY_JOB = 'outbox-relay';
const QUEUE_NAME = 'dealgo-workers';

/**
 * Starts BullMQ repeatable jobs when REDIS_URL is reachable.
 * Non-prod: soft-fails to setInterval if Redis is missing/down.
 * Production without Redis: logs and skips (does not pretend jobs succeeded).
 * NODE_ENV=test: no background timers (tests call services directly).
 */
@Injectable()
export class WorkersBootstrap implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(WorkersBootstrap.name);
  private queue: Queue | null = null;
  private worker: Worker | null = null;
  private intervals: NodeJS.Timeout[] = [];

  constructor(
    private readonly config: ConfigService<AppEnv, true>,
    private readonly rideExpiry: RideExpiryService,
    private readonly outboxRelay: OutboxRelayService,
  ) {}

  async onModuleInit(): Promise<void> {
    const nodeEnv = this.config.get('NODE_ENV', { infer: true });
    if (nodeEnv === 'test') {
      return;
    }

    const redisUrl = this.config.get('REDIS_URL', { infer: true });
    const rideIntervalMs = this.config.get('RIDE_EXPIRY_INTERVAL_MS', { infer: true });
    const outboxIntervalMs = this.config.get('OUTBOX_RELAY_INTERVAL_MS', { infer: true });

    if (redisUrl) {
      const started = await this.startBullMq(redisUrl, rideIntervalMs, outboxIntervalMs);
      if (started) {
        return;
      }
      if (nodeEnv === 'production') {
        this.logger.error({
          msg: 'workers.redis_unavailable',
          detail: 'BullMQ workers not started; REDIS_URL present but unreachable',
        });
        throw new Error('BullMQ workers cannot start; REDIS_URL is unreachable in production');
      }
      this.logger.warn({
        msg: 'workers.redis_fallback_interval',
        detail: 'Redis unavailable; using in-process interval workers (non-prod)',
      });
    } else if (nodeEnv === 'production') {
      this.logger.error({
        msg: 'workers.redis_missing',
        detail: 'REDIS_URL unset in production; background workers disabled',
      });
      throw new Error('REDIS_URL must be configured in production for background workers');
    } else {
      this.logger.warn({
        msg: 'workers.interval_mode',
        detail: 'REDIS_URL unset; using in-process interval workers (non-prod)',
      });
    }

    this.startIntervals(rideIntervalMs, outboxIntervalMs);
  }

  async onModuleDestroy(): Promise<void> {
    for (const timer of this.intervals) {
      clearInterval(timer);
    }
    this.intervals = [];
    await this.worker?.close();
    await this.queue?.close();
    this.worker = null;
    this.queue = null;
  }

  private async startBullMq(
    redisUrl: string,
    rideIntervalMs: number,
    outboxIntervalMs: number,
  ): Promise<boolean> {
    try {
      const connection = parseRedisConnection(redisUrl);
      this.queue = new Queue(QUEUE_NAME, { connection });
      await this.queue.waitUntilReady();

      await this.queue.add(
        RIDE_EXPIRY_JOB,
        {},
        {
          repeat: { every: rideIntervalMs },
          removeOnComplete: 100,
          removeOnFail: 100,
          jobId: RIDE_EXPIRY_JOB,
        },
      );
      await this.queue.add(
        OUTBOX_RELAY_JOB,
        {},
        {
          repeat: { every: outboxIntervalMs },
          removeOnComplete: 100,
          removeOnFail: 100,
          jobId: OUTBOX_RELAY_JOB,
        },
      );

      this.worker = new Worker(
        QUEUE_NAME,
        async (job) => {
          if (job.name === RIDE_EXPIRY_JOB) {
            await this.rideExpiry.runOnce();
            return;
          }
          if (job.name === OUTBOX_RELAY_JOB) {
            await this.outboxRelay.relayOnce();
          }
        },
        { connection },
      );
      this.worker.on('failed', (job, error) => {
        this.logger.warn({
          msg: 'workers.job_failed',
          job: job?.name,
          error: error.message,
        });
      });
      this.logger.log({ msg: 'workers.bullmq_started', queue: QUEUE_NAME });
      return true;
    } catch (error) {
      this.logger.warn({
        msg: 'workers.bullmq_start_failed',
        error: error instanceof Error ? error.message : 'unknown',
      });
      await this.worker?.close().catch(() => undefined);
      await this.queue?.close().catch(() => undefined);
      this.worker = null;
      this.queue = null;
      return false;
    }
  }

  private startIntervals(rideIntervalMs: number, outboxIntervalMs: number): void {
    this.intervals.push(
      setInterval(() => {
        void this.rideExpiry.runOnce().catch((error: unknown) => {
          this.logger.warn({
            msg: 'workers.ride_expiry_failed',
            error: error instanceof Error ? error.message : 'unknown',
          });
        });
      }, rideIntervalMs),
    );
    this.intervals.push(
      setInterval(() => {
        void this.outboxRelay.relayOnce().catch((error: unknown) => {
          this.logger.warn({
            msg: 'workers.outbox_relay_failed',
            error: error instanceof Error ? error.message : 'unknown',
          });
        });
      }, outboxIntervalMs),
    );
    for (const timer of this.intervals) {
      timer.unref?.();
    }
  }
}

function parseRedisConnection(redisUrl: string): {
  host: string;
  port: number;
  username?: string;
  password?: string;
  tls?: object;
} {
  const target = new URL(redisUrl);
  const port = target.port ? Number(target.port) : 6379;
  const username = decodeURIComponent(target.username) || undefined;
  const password = decodeURIComponent(target.password) || undefined;
  return {
    host: target.hostname,
    port,
    ...(username ? { username } : {}),
    ...(password ? { password } : {}),
    ...(target.protocol === 'rediss:' ? { tls: {} } : {}),
  };
}
