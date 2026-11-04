/**
 * DEC-PROD-031 (rev 2026-10-24): adaptive driver GPS reporting + server-side validation.
 *
 * Sourced reference points (see docs/06-data-api/realtime-api-contract.md §Driver location):
 * - Google Fleet Engine Driver SDK: default report every 10 s, supported 5–60 s.
 * - Uber driver-location webhooks: every 4 s during a trip.
 * The concrete DealGo numbers below are DRAFT defaults, overridable via env.
 */
export type DriverLocationMode = 'ON_TRIP' | 'IDLE';

export type DriverLocationPolicy = {
  mode: DriverLocationMode;
  /** Client sends at most once per interval… */
  intervalMs: number;
  /** …and only when it moved at least this far, … */
  minDistanceM: number;
  /** …except a keep-alive fix after this much silence. */
  maxSilenceMs: number;
};

export type DriverLocationPolicyConfig = {
  onTripIntervalMs: number;
  idleIntervalMs: number;
  onTripMinDistanceM: number;
  idleMinDistanceM: number;
  maxSilenceMs: number;
  /** Server drops fixes from the same driver arriving closer than this. */
  minAcceptIntervalMs: number;
};

export const DEFAULT_DRIVER_LOCATION_POLICY: DriverLocationPolicyConfig = {
  onTripIntervalMs: 5_000,
  idleIntervalMs: 15_000,
  onTripMinDistanceM: 10,
  idleMinDistanceM: 50,
  maxSilenceMs: 30_000,
  minAcceptIntervalMs: 1_000,
};

/** DRAFT guards (not from a source): clock skew, max plausible speed, worst usable accuracy. */
export const MAX_FUTURE_SKEW_MS = 30_000;
export const MAX_PLAUSIBLE_SPEED_MPS = 70;
export const MAX_ACCEPTED_ACCURACY_M = 200;

export function policyFor(mode: DriverLocationMode, cfg: DriverLocationPolicyConfig): DriverLocationPolicy {
  return mode === 'ON_TRIP'
    ? { mode, intervalMs: cfg.onTripIntervalMs, minDistanceM: cfg.onTripMinDistanceM, maxSilenceMs: cfg.maxSilenceMs }
    : { mode, intervalMs: cfg.idleIntervalMs, minDistanceM: cfg.idleMinDistanceM, maxSilenceMs: cfg.maxSilenceMs * 2 };
}

export type LocationRejectReason =
  | 'RATE_LIMITED'
  | 'STALE'
  | 'FUTURE'
  | 'OUT_OF_ORDER'
  | 'LOW_ACCURACY'
  | 'IMPLAUSIBLE_JUMP'
  | 'MOCK_LOCATION';

export type IncomingFix = { lat: number; lng: number; at: Date; accuracyM?: number; isMocked?: boolean };
export type PreviousFix = { lat: number; lng: number; at: Date } | null;

/** Pure validation; returns null when the fix should be stored and fanned out. */
export function rejectReason(
  fix: IncomingFix,
  previous: PreviousFix,
  now: Date,
  freshMs: number,
): LocationRejectReason | null {
  if (fix.isMocked) {
    return 'MOCK_LOCATION';
  }
  if (fix.at.getTime() - now.getTime() > MAX_FUTURE_SKEW_MS) {
    return 'FUTURE';
  }
  if (now.getTime() - fix.at.getTime() > freshMs) {
    return 'STALE';
  }
  if (fix.accuracyM !== undefined && fix.accuracyM > MAX_ACCEPTED_ACCURACY_M) {
    return 'LOW_ACCURACY';
  }
  if (previous) {
    const dtMs = fix.at.getTime() - previous.at.getTime();
    if (dtMs <= 0) {
      return 'OUT_OF_ORDER';
    }
    const speed = haversineM(previous, fix) / (dtMs / 1000);
    if (speed > MAX_PLAUSIBLE_SPEED_MPS) {
      return 'IMPLAUSIBLE_JUMP';
    }
  }
  return null;
}

export function haversineM(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const r = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.min(1, Math.sqrt(h)));
}
