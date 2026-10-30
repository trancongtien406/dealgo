/** Minimal EventSource surface (lets tests use a fake without jsdom). */
export interface EventSourceLike {
  readyState: number;
  onopen: ((ev: unknown) => void) | null;
  onerror: ((ev: unknown) => void) | null;
  addEventListener(type: string, listener: (ev: { data: string }) => void): void;
  close(): void;
}

export type OpsStreamHandlers = {
  /** A `monitor` hint: re-GET the monitor snapshot. */
  onMonitor: () => void;
  /** A `systemErrors` hint: re-GET the list/count. */
  onSystemErrors: () => void;
  /** Reopened after a drop: hints may have been missed, so refetch both snapshots. */
  onReconnect: () => void;
};

export const OPS_EVENTS_URL = "/api/ops/events";
const CLOSED = 2;
/** Browser auto-retry gives up on non-2xx (e.g. 401); retry ourselves with backoff. */
const RETRY_MIN_MS = 5_000;
const RETRY_MAX_MS = 60_000;

/**
 * Framework-free controller for the admin SSE stream. REST stays the source of truth:
 * the first open does nothing, every later open (reconnect) triggers a refetch.
 */
export function openOpsEventStream(
  handlers: OpsStreamHandlers,
  create: (url: string) => EventSourceLike = (url) =>
    new EventSource(url) as unknown as EventSourceLike,
  timers: { setTimeout: typeof setTimeout; clearTimeout: typeof clearTimeout } = globalThis,
): () => void {
  let source: EventSourceLike | null = null;
  let retryTimer: ReturnType<typeof setTimeout> | null = null;
  let opened = false;
  let dropped = false;
  let retryMs = RETRY_MIN_MS;
  let disposed = false;

  const connect = () => {
    if (disposed) return;
    const es = create(OPS_EVENTS_URL);
    source = es;
    es.onopen = () => {
      retryMs = RETRY_MIN_MS;
      if (opened && dropped) handlers.onReconnect();
      opened = true;
      dropped = false;
    };
    es.onerror = () => {
      dropped = true;
      if (es.readyState === CLOSED && !disposed) {
        es.close();
        source = null;
        retryTimer = timers.setTimeout(() => {
          retryTimer = null;
          connect();
        }, retryMs);
        retryMs = Math.min(retryMs * 2, RETRY_MAX_MS);
      }
    };
    es.addEventListener("monitor", () => handlers.onMonitor());
    es.addEventListener("systemErrors", () => handlers.onSystemErrors());
  };

  connect();
  return () => {
    disposed = true;
    if (retryTimer) timers.clearTimeout(retryTimer);
    retryTimer = null;
    source?.close();
    source = null;
  };
}
