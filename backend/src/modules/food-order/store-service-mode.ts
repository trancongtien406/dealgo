/** DEC-PROD-026 — merchant intake mode (M024). */
export const STORE_SERVICE_MODES = ['OPEN', 'BUSY', 'PAUSED'] as const;
export type StoreServiceMode = (typeof STORE_SERVICE_MODES)[number];

/** Auto-resume presets offered by M024; null = manual. */
export const STORE_RESUME_MINUTES = [30, 60, 120] as const;

export type StoreServiceState = {
  serviceMode: StoreServiceMode;
  serviceModeUntil: string | null;
};

/**
 * The mode customers and the order guard see: a BUSY/PAUSED mode whose resume time has passed is
 * OPEN again, without needing a job to flip the row.
 */
export function effectiveServiceMode(
  mode: StoreServiceMode | null | undefined,
  until: Date | null | undefined,
  now: Date = new Date(),
): StoreServiceState {
  const current = mode ?? 'OPEN';
  if (current === 'OPEN') {
    return { serviceMode: 'OPEN', serviceModeUntil: null };
  }
  if (until && until.getTime() <= now.getTime()) {
    return { serviceMode: 'OPEN', serviceModeUntil: null };
  }
  return { serviceMode: current, serviceModeUntil: until ? until.toISOString() : null };
}

export function resumeAt(
  mode: StoreServiceMode,
  resumeAfterMinutes: number | null | undefined,
  now: Date,
): Date | null {
  if (mode === 'OPEN' || !resumeAfterMinutes) {
    return null;
  }
  return new Date(now.getTime() + resumeAfterMinutes * 60_000);
}
