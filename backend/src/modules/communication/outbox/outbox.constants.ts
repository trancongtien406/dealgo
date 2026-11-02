export const OUTBOX_REPOSITORY = Symbol('OUTBOX_REPOSITORY');

/** REL-001: a row failing this many deliveries is dead-lettered (kept, never retried). */
export const OUTBOX_MAX_ATTEMPTS = 10;
const OUTBOX_BACKOFF_BASE_MS = 5_000;
const OUTBOX_BACKOFF_MAX_MS = 15 * 60_000;

/** REL-001: exponential retry delay after the n-th failed attempt (5s, 10s, 20s … capped 15 min). */
export function outboxBackoffMs(attempts: number): number {
  const exp = Math.max(0, attempts - 1);
  return Math.min(OUTBOX_BACKOFF_MAX_MS, OUTBOX_BACKOFF_BASE_MS * 2 ** Math.min(exp, 20));
}
