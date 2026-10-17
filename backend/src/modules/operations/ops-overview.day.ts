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
