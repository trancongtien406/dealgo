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

/**
 * Minutes from today's local midnight at which `row` stops serving — or null when it is not
 * serving now. The single definition shared by the availability gate and the closing time, so
 * the two can never disagree. An overnight shift that started yesterday closes in the early
 * hours of today, and keeps serving past midnight even when today is a closed day; a shift
 * that starts today and runs past midnight closes tomorrow.
 */
function shiftCloseOffset(
  row: WeeklyHourRow,
  today: VnClock,
  yesterday: VnClock,
  lastOrderMinutes: number,
  closedOn: (date: string) => boolean,
): number | null {
  const ends = shiftOrderEnd(row, lastOrderMinutes);
  if (
    row.weekday === today.weekday &&
    !closedOn(today.date) &&
    row.opensMinute <= today.minute &&
    today.minute < ends
  ) {
    return isOvernight(row) ? row.closesMinute + 1440 : row.closesMinute;
  }
  if (
    row.weekday === yesterday.weekday &&
    isOvernight(row) &&
    !closedOn(yesterday.date) &&
    today.minute + 1440 < ends
  ) {
    return row.closesMinute;
  }
  return null;
}

function closedOnDate(schedule: StoreSchedule): (date: string) => boolean {
  return (date) => schedule.closures.some((closure) => closure.date === date);
}

/** Whether the schedule accepts a new order at `now` (closures, weekly hours, cut-off). */
export function withinSchedule(schedule: StoreSchedule, now: Date): boolean {
  const today = vnClock(now);
  const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
  const closedOn = closedOnDate(schedule);
  if (!schedule.hoursConfigured) {
    return !closedOn(today.date);
  }
  const last = schedule.lastOrderMinutes;
  return schedule.hours.some(
    (row) => shiftCloseOffset(row, today, yesterday, last, closedOn) !== null,
  );
}

/**
 * Closing time (HH:mm, Vietnam local) of the shift that is taking orders right now.
 * Null when no shift is serving — the store has no hours, is closed, or is closed for the
 * whole day — so a card never prints "Mở đến …" for a store that is not open. Two rows can
 * serve the same instant (yesterday's overnight shift and today's opening); the shift that
 * closes first wins, matching the SQL tie-break.
 */
export function closesAtToday(
  schedule: StoreSchedule,
  now: Date = new Date(),
): string | null {
  const today = vnClock(now);
  const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
  const closedOn = closedOnDate(schedule);
  let earliest: number | null = null;
  for (const row of schedule.hours) {
    const closes = shiftCloseOffset(
      row,
      today,
      yesterday,
      schedule.lastOrderMinutes,
      closedOn,
    );
    if (closes !== null && (earliest === null || closes < earliest)) {
      earliest = closes;
    }
  }
  return earliest === null ? null : formatClock(earliest % 1440);
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
