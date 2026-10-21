/**
 * DEC-PROD-027 — M023 opening hours, special closed days and the last-order cut-off.
 * All times are Vietnam local time (UTC+7, no DST). A store that never saved hours
 * (`hoursConfigured = false`) is open around the clock, so existing stores keep working.
 */
import { effectiveServiceMode, type StoreServiceMode } from './store-service-mode.js';

export const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
export const LAST_ORDER_MINUTES = [0, 15, 30, 45, 60] as const;
export const MAX_STORE_CLOSURES = 60;

/**
 * weekday: 1 = Monday … 7 = Sunday (ISO). Minutes from local midnight; closes ≤ 1440.
 * closes < opens is an overnight shift (e.g. 18:00–02:00) that ends the next morning; it belongs
 * to the day it starts, so a closure on that start date cancels the whole shift (DEC-PROD-029).
 */
export type WeeklyHourRow = { weekday: number; opensMinute: number; closesMinute: number };
export type ClosureRow = { date: string; note: string | null };

export type StoreSchedule = {
  hoursConfigured: boolean;
  lastOrderMinutes: number;
  hours: WeeklyHourRow[];
  closures: ClosureRow[];
};

export type StoreScheduleView = {
  hoursConfigured: boolean;
  lastOrderMinutes: number;
  weekly: { weekday: number; opensAt: string; closesAt: string }[];
  closures: ClosureRow[];
};

export type StoreClosedReason = 'PAUSED' | 'CLOSED';

export type StoreAvailability = {
  openNow: boolean;
  closedReason: StoreClosedReason | null;
};

export type VnClock = { weekday: number; minute: number; date: string };

export function vnClock(now: Date): VnClock {
  const local = new Date(now.getTime() + VN_OFFSET_MS);
  const day = local.getUTCDay();
  return {
    weekday: day === 0 ? 7 : day,
    minute: local.getUTCHours() * 60 + local.getUTCMinutes(),
    date: local.toISOString().slice(0, 10),
  };
}

export function parseClock(value: string): number | null {
  const match = /^([01]\d|2[0-4]):([0-5]\d)$/.exec(value);
  if (!match) {
    return null;
  }
  const minute = Number(match[1]) * 60 + Number(match[2]);
  return minute > 1440 ? null : minute;
}

export function formatClock(minute: number): string {
  const h = Math.floor(minute / 60);
  const m = minute % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export function isOvernight(row: Pick<WeeklyHourRow, 'opensMinute' | 'closesMinute'>): boolean {
  return row.closesMinute < row.opensMinute;
}

/** Last minute (exclusive) a shift takes orders, counted from its start day's midnight. */
export function shiftOrderEnd(
  row: Pick<WeeklyHourRow, 'opensMinute' | 'closesMinute'>,
  lastOrderMinutes: number,
): number {
  return (isOvernight(row) ? row.closesMinute + 1440 : row.closesMinute) - lastOrderMinutes;
}

/** Whether the schedule accepts a new order at `now` (closures, weekly hours, cut-off). */
export function withinSchedule(schedule: StoreSchedule, now: Date): boolean {
  const today = vnClock(now);
  const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
  const closedOn = (date: string) => schedule.closures.some((closure) => closure.date === date);
  if (!schedule.hoursConfigured) {
    return !closedOn(today.date);
  }
  const last = schedule.lastOrderMinutes;
  return schedule.hours.some(
    (row) =>
      (row.weekday === today.weekday &&
        !closedOn(today.date) &&
        row.opensMinute <= today.minute &&
        today.minute < shiftOrderEnd(row, last)) ||
      (row.weekday === yesterday.weekday &&
        isOvernight(row) &&
        !closedOn(yesterday.date) &&
        today.minute + 1440 < shiftOrderEnd(row, last)),
  );
}

export function storeAvailability(
  mode: StoreServiceMode | null | undefined,
  until: Date | null | undefined,
  schedule: StoreSchedule,
  now: Date = new Date(),
): StoreAvailability {
  if (effectiveServiceMode(mode, until, now).serviceMode === 'PAUSED') {
    return { openNow: false, closedReason: 'PAUSED' };
  }
  if (!withinSchedule(schedule, now)) {
    return { openNow: false, closedReason: 'CLOSED' };
  }
  return { openNow: true, closedReason: null };
}

export function scheduleView(schedule: StoreSchedule): StoreScheduleView {
  return {
    hoursConfigured: schedule.hoursConfigured,
    lastOrderMinutes: schedule.lastOrderMinutes,
    weekly: [...schedule.hours]
      .sort((a, b) => a.weekday - b.weekday)
      .map((row) => ({
        weekday: row.weekday,
        opensAt: formatClock(row.opensMinute),
        closesAt: formatClock(row.closesMinute),
      })),
    closures: [...schedule.closures].sort((a, b) => a.date.localeCompare(b.date)),
  };
}

export const ALWAYS_OPEN: StoreSchedule = {
  hoursConfigured: false,
  lastOrderMinutes: 0,
  hours: [],
  closures: [],
};

export type ScheduleInput = {
  weekly: { weekday: number; opensAt: string; closesAt: string }[];
  closures: { date: string; note?: string | null }[];
  lastOrderMinutes: number;
};

/** Validates merchant input; returns rows or a human-readable problem (400 FOOD_HOURS_INVALID). */
export function normalizeSchedule(
  input: ScheduleInput,
): { ok: true; schedule: StoreSchedule } | { ok: false; problem: string } {
  const seen = new Set<number>();
  const hours: WeeklyHourRow[] = [];
  for (const day of input.weekly) {
    if (seen.has(day.weekday)) {
      return { ok: false, problem: `weekday ${day.weekday} appears twice` };
    }
    seen.add(day.weekday);
    const opens = parseClock(day.opensAt);
    const parsedCloses = parseClock(day.closesAt);
    // 00:00 as a closing time is midnight at the end of the day, not an overnight shift.
    const closes = parsedCloses === 0 ? 1440 : parsedCloses;
    if (opens === null || closes === null || opens >= 1440) {
      return { ok: false, problem: `weekday ${day.weekday} has an invalid time` };
    }
    if (closes === opens) {
      return { ok: false, problem: `weekday ${day.weekday} must not close when it opens` };
    }
    hours.push({ weekday: day.weekday, opensMinute: opens, closesMinute: closes });
  }
  const dates = new Set<string>();
  const closures: ClosureRow[] = [];
  for (const closure of input.closures) {
    const parsed = new Date(`${closure.date}T00:00:00.000Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== closure.date) {
      return { ok: false, problem: `invalid date ${closure.date}` };
    }
    if (dates.has(closure.date)) {
      return { ok: false, problem: `date ${closure.date} appears twice` };
    }
    dates.add(closure.date);
    closures.push({ date: closure.date, note: closure.note?.trim() || null });
  }
  return {
    ok: true,
    schedule: {
      hoursConfigured: true,
      lastOrderMinutes: input.lastOrderMinutes,
      hours,
      closures,
    },
  };
}
