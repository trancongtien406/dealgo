/**
 * Lifetime terminal jobs still attributed to a driver (assignedDriverId), DEC-PROD-034.
 * `finished` = completed + cancelled/failed after assignment. Jobs reassigned by Ops move to
 * the new driver, so they never count against the first one.
 */
export type DriverJobCounts = { completed: number; finished: number };

export const EMPTY_JOB_COUNTS: DriverJobCounts = { completed: 0, finished: 0 };

/** Adds `other` into `into` (per driver). */
export function mergeJobCounts(
  into: Map<string, DriverJobCounts>,
  other: Map<string, DriverJobCounts>,
): Map<string, DriverJobCounts> {
  for (const [driverId, counts] of other) {
    const current = into.get(driverId) ?? { ...EMPTY_JOB_COUNTS };
    into.set(driverId, {
      completed: current.completed + counts.completed,
      finished: current.finished + counts.finished,
    });
  }
  return into;
}

/** Completed share of finished jobs, 0..1 rounded to 3 places; null when nothing finished. */
export function completionRate(counts: DriverJobCounts): number | null {
  if (counts.finished <= 0) {
    return null;
  }
  return Math.round((counts.completed / counts.finished) * 1000) / 1000;
}
