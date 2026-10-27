import {
  OPS_KPI_TODAY_TIMEZONE,
  OPS_KPI_TODAY_UTC_OFFSET_HOURS,
} from './ops-overview.constants.js';

/**
 * Start of the calendar day in Asia/Ho_Chi_Minh (UTC+7, no DST), as a UTC Date.
 * “Today” KPIs use `updatedAt >= startOfToday` with this timezone — not UTC midnight.
 */
export function startOfTodayHoChiMinh(now = new Date()): Date {
  const offsetMs = OPS_KPI_TODAY_UTC_OFFSET_HOURS * 3_600_000;
  const local = new Date(now.getTime() + offsetMs);
  return new Date(
    Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) - offsetMs,
  );
}

export function todayTimezoneLabel(): typeof OPS_KPI_TODAY_TIMEZONE {
  return OPS_KPI_TODAY_TIMEZONE;
}

const DAY_MS = 86_400_000;
const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

/** Vietnam calendar day (YYYY-MM-DD) that contains `at`. */
export function hoChiMinhDayKey(at: Date): string {
  const local = new Date(at.getTime() + OPS_KPI_TODAY_UTC_OFFSET_HOURS * 3_600_000);
  return local.toISOString().slice(0, 10);
}

/** UTC instant of 00:00 Asia/Ho_Chi_Minh on `day` (YYYY-MM-DD); null when malformed. */
export function startOfHoChiMinhDay(day: string): Date | null {
  if (!DAY_KEY.test(day)) {
    return null;
  }
  const utcMidnight = Date.parse(`${day}T00:00:00.000Z`);
  if (Number.isNaN(utcMidnight) || new Date(utcMidnight).toISOString().slice(0, 10) !== day) {
    return null;
  }
  return new Date(utcMidnight - OPS_KPI_TODAY_UTC_OFFSET_HOURS * 3_600_000);
}

export type HoChiMinhDayRange = {
  from: string;
  to: string;
  /** Inclusive lower bound (00:00 ICT on `from`). */
  start: Date;
  /** Exclusive upper bound (00:00 ICT on the day after `to`). */
  end: Date;
  days: string[];
};

/**
 * Inclusive range of Vietnam business days. Missing bounds default to today; returns null when
 * a bound is malformed, `from` is after `to`, or the range is longer than `maxDays`.
 */
export function hoChiMinhDayRange(
  input: { from?: string | null; to?: string | null },
  now = new Date(),
  maxDays = 92,
): HoChiMinhDayRange | null {
  const today = hoChiMinhDayKey(now);
  const from = input.from?.trim() || input.to?.trim() || today;
  const to = input.to?.trim() || from;
  const start = startOfHoChiMinhDay(from);
  const lastStart = startOfHoChiMinhDay(to);
  if (!start || !lastStart || lastStart.getTime() < start.getTime()) {
    return null;
  }
  const count = Math.round((lastStart.getTime() - start.getTime()) / DAY_MS) + 1;
  if (count > maxDays) {
    return null;
  }
  const days = Array.from({ length: count }, (_, i) => hoChiMinhDayKey(new Date(start.getTime() + i * DAY_MS)));
  return { from, to, start, end: new Date(lastStart.getTime() + DAY_MS), days };
}
