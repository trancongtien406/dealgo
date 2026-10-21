/** Percent with up to 2 decimals → basis points (12.5 % → 1250). */
export function percentToBps(percent: number): number {
  if (!Number.isFinite(percent) || percent < 0 || percent > 100) {
    throw new RangeError(`Platform fee percent out of range: ${percent}`);
  }
  return Math.round(percent * 100);
}

/** Fee rounded half-up to whole VND; net is always fare - fee. */
export function splitFare(
  fareVnd: number,
  feeBps: number,
): { feeVnd: number; netVnd: number } {
  if (!Number.isSafeInteger(fareVnd) || fareVnd < 0) {
    throw new RangeError(`Invalid fare: ${fareVnd}`);
  }
  if (!Number.isInteger(feeBps) || feeBps < 0 || feeBps > 10_000) {
    throw new RangeError(`Invalid fee bps: ${feeBps}`);
  }
  const feeVnd = Math.round((fareVnd * feeBps) / 10_000);
  return { feeVnd, netVnd: fareVnd - feeVnd };
}
