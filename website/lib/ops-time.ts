/** Standardized Vietnamese time formatters (Asia/Ho_Chi_Minh display). */

export const TIMEZONE_VN = "Asia/Ho_Chi_Minh";

export type DateInput = string | number | Date | null | undefined;

function toValidDate(input: DateInput): Date | null {
  if (input == null || input === "") return null;
  const date = input instanceof Date ? input : new Date(input);
  return Number.isNaN(date.getTime()) ? null : date;
}

const clockFormat = new Intl.DateTimeFormat("vi-VN", {
  hour: "2-digit",
  minute: "2-digit",
  timeZone: TIMEZONE_VN,
});

const dateFormat = new Intl.DateTimeFormat("vi-VN", {
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
  timeZone: TIMEZONE_VN,
});

const dateTimeFormat = new Intl.DateTimeFormat("vi-VN", {
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  timeZone: TIMEZONE_VN,
});

const stampFormat = new Intl.DateTimeFormat("vi-VN", {
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  timeZone: TIMEZONE_VN,
});

/** Formats time clock only: "14:30" */
export function formatOpsClock(input: DateInput): string {
  const date = toValidDate(input);
  return date ? clockFormat.format(date) : "—";
}

/** Formats date only: "17/10/2026" */
export function formatOpsDate(input: DateInput): string {
  const date = toValidDate(input);
  return date ? dateFormat.format(date) : "—";
}

/** Formats date and time: "17/10/2026, 14:30" */
export function formatOpsDateTime(input: DateInput): string {
  const date = toValidDate(input);
  return date ? dateTimeFormat.format(date) : "—";
}

/** Formats date and time with seconds: "17/10/2026, 14:30:25" */
export function formatOpsStamp(input: DateInput): string {
  const date = toValidDate(input);
  return date ? stampFormat.format(date) : "—";
}

/** Formats human-friendly relative time: "Vừa xong", "5 phút trước", or clock time. */
export function formatOpsRelative(input: DateInput, now = Date.now()): string {
  const date = toValidDate(input);
  if (!date) {
    return "—";
  }
  const deltaSec = Math.max(0, Math.floor((now - date.getTime()) / 1000));
  if (deltaSec < 60) {
    return "Vừa xong";
  }
  const minutes = Math.floor(deltaSec / 60);
  if (minutes < 60) {
    return `${minutes} phút trước`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours} giờ trước`;
  }
  return formatOpsClock(date);
}
