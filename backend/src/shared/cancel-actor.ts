/**
 * DEC-PROD-035: who ended a CANCELLED ride or food order (null while not cancelled).
 * Only DRIVER cancellations count against a driver's completion rate.
 */
export type CancelActorName = 'CUSTOMER' | 'DRIVER' | 'MERCHANT' | 'OPS' | 'SYSTEM';

export const CANCEL_ACTORS: readonly CancelActorName[] = [
  'CUSTOMER',
  'DRIVER',
  'MERCHANT',
  'OPS',
  'SYSTEM',
];

/**
 * DEC-PROD-035: a CANCELLED job only counts as an unfinished job of the driver when the
 * driver cancelled it. Customer / merchant / Ops / system cancellations are excluded.
 */
export function cancellationCountsAgainstDriver(
  status: string,
  cancelledBy: CancelActorName | null | undefined,
): boolean {
  return status !== 'CANCELLED' || cancelledBy === 'DRIVER';
}
