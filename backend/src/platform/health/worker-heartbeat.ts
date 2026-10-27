import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service.js';

export const WORKER_HEARTBEAT_NAME = 'dealgo-workers';

export type WorkerHeartbeatRecord = { name: string; instance: string; startedAt: Date; beatAt: Date };

export interface WorkerHeartbeatStore {
  beat(input: { name: string; instance: string; startedAt: Date; meta?: Record<string, unknown> }, now: Date): Promise<void>;
  latest(name: string): Promise<WorkerHeartbeatRecord | null>;
  /** createdAt of the oldest unprocessed outbox row, or null when the outbox is drained. */
  oldestPendingOutboxAt(): Promise<Date | null>;
}

export const WORKER_HEARTBEAT_STORE = Symbol('WORKER_HEARTBEAT_STORE');

export type WorkerStatus = 'up' | 'stale' | 'missing' | 'unknown';

export function workerStatus(record: WorkerHeartbeatRecord | null, staleMs: number, now: Date): WorkerStatus {
  if (!record) {
    return 'missing';
  }
  return now.getTime() - record.beatAt.getTime() > staleMs ? 'stale' : 'up';
}

export function outboxLagMs(oldestPending: Date | null, now: Date): number {
  return oldestPending ? Math.max(0, now.getTime() - oldestPending.getTime()) : 0;
}

/** worker_heartbeats + outbox_messages via Prisma (DEC-PROD-053). */
@Injectable()
export class PrismaWorkerHeartbeatStore implements WorkerHeartbeatStore {
  constructor(private readonly prisma: PrismaService) {}

  async beat(
    input: { name: string; instance: string; startedAt: Date; meta?: Record<string, unknown> },
    now: Date,
  ): Promise<void> {
    const db = this.prisma.db();
    if (!db) {
      return;
    }
    const meta = (input.meta ?? {}) as object;
    await db.workerHeartbeat.upsert({
      where: { name: input.name },
      create: { name: input.name, instance: input.instance, startedAt: input.startedAt, beatAt: now, meta },
      update: { instance: input.instance, startedAt: input.startedAt, beatAt: now, meta },
    });
  }

  async latest(name: string): Promise<WorkerHeartbeatRecord | null> {
    const db = this.prisma.db();
    if (!db) {
      return null;
    }
    return db.workerHeartbeat.findUnique({
      where: { name },
      select: { name: true, instance: true, startedAt: true, beatAt: true },
    });
  }

  async oldestPendingOutboxAt(): Promise<Date | null> {
    const db = this.prisma.db();
    if (!db) {
      return null;
    }
    const row = await db.outboxMessage.findFirst({
      where: { processedAt: null },
      orderBy: { createdAt: 'asc' },
      select: { createdAt: true },
    });
    return row?.createdAt ?? null;
  }
}
