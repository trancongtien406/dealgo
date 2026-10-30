import { Injectable, Logger } from '@nestjs/common';

/**
 * Admin live hints (t50u follow-up, owner: "Làm luôn realtime cho admin bằng SSE").
 * They are hints only: the admin web re-GETs the REST snapshot, which stays the source of truth.
 */
export type OpsEvent =
  | { type: 'monitor'; reason: string; aggregateType?: string; at: string }
  | { type: 'systemErrors'; reason: string; count?: number | null; at: string };

export type OpsEventListener = (event: OpsEvent) => void;

/** Cross-process name used with Socket.IO `serverSideEmit` (worker → API nodes). */
export const OPS_HINT_SERVER_EVENT = 'dealgo:opsHint';

export function isOpsEvent(raw: unknown): raw is OpsEvent {
  if (!raw || typeof raw !== 'object') return false;
  const r = raw as Record<string, unknown>;
  return (r.type === 'monitor' || r.type === 'systemErrors') && typeof r.reason === 'string' && typeof r.at === 'string';
}

/** In-process fan-out to SSE subscribers. Listener errors are logged, never thrown. */
@Injectable()
export class OpsEventBus {
  private readonly logger = new Logger(OpsEventBus.name);
  private readonly listeners = new Set<OpsEventListener>();
  private readonly countListeners = new Set<(count: number) => void>();

  subscribe(listener: OpsEventListener): () => void {
    this.listeners.add(listener);
    this.notifyCount();
    return () => {
      if (this.listeners.delete(listener)) {
        this.notifyCount();
      }
    };
  }

  get subscriberCount(): number {
    return this.listeners.size;
  }

  /** Lets a watcher run only while someone is listening. */
  onSubscriberCount(listener: (count: number) => void): () => void {
    this.countListeners.add(listener);
    return () => this.countListeners.delete(listener);
  }

  publish(event: OpsEvent): void {
    for (const listener of [...this.listeners]) {
      try {
        listener(event);
      } catch (error) {
        this.logger.warn({ msg: 'ops_events.listener_failed', error: (error as Error).message });
      }
    }
  }

  private notifyCount(): void {
    for (const listener of [...this.countListeners]) {
      try {
        listener(this.listeners.size);
      } catch {
        // ignore
      }
    }
  }
}
