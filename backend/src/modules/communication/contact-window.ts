/**
 * Contact window policy for in-app chat and voice communications.
 */

const RIDE_TERMINAL = new Set(['COMPLETED', 'CANCELLED', 'EXPIRED']);
const FOOD_TERMINAL = new Set(['DELIVERED', 'FAILED', 'CANCELLED']);

export type ContactAggregateKind = 'ride' | 'food';

export function isTerminalContactStatus(kind: ContactAggregateKind, status: string): boolean {
  if (kind === 'ride') {
    return RIDE_TERMINAL.has(status);
  }
  return FOOD_TERMINAL.has(status);
}

/**
 * Active (non-terminal) transactions allow contact.
 * Terminal statuses allow contact only within `windowMinutes` after `updatedAt`.
 */
export function isWithinContactWindow(input: {
  kind: ContactAggregateKind;
  status: string;
  updatedAt: Date;
  now: Date;
  windowMinutes: number;
}): boolean {
  if (!Number.isFinite(input.windowMinutes) || input.windowMinutes <= 0) {
    return false;
  }
  if (!isTerminalContactStatus(input.kind, input.status)) {
    return true;
  }
  const elapsedMs = input.now.getTime() - input.updatedAt.getTime();
  return elapsedMs >= 0 && elapsedMs <= input.windowMinutes * 60_000;
}
