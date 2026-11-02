import type { OutboxPendingRow } from './outbox.repository.js';

/**
 * t82u: aggregate types handled by a feature module instead of the relay's built-in
 * fanout/push steps (avoids OutboxModule importing every feature). A handler throwing
 * releases the row for retry, like the built-in steps.
 */
export type OutboxAggregateHandler = (row: OutboxPendingRow, now: Date) => Promise<void>;

const handlers = new Map<string, OutboxAggregateHandler>();

export function registerOutboxHandler(aggregateType: string, handler: OutboxAggregateHandler): void {
  handlers.set(aggregateType, handler);
}

export function outboxHandlerFor(aggregateType: string): OutboxAggregateHandler | undefined {
  return handlers.get(aggregateType);
}
