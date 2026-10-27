import { BadRequestException } from '@nestjs/common';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, Matches } from 'class-validator';
import { startOfHoChiMinhDay } from './ops-overview.day.js';

const DAY_MS = 86_400_000;
const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

/** Half-open UTC window `[start, end)`; either bound may be open. */
export type OpsDateWindow = { start?: Date; end?: Date };

/**
 * `from` / `to` query params shared by Ops list endpoints. Both are Vietnam business days
 * (Asia/Ho_Chi_Minh, YYYY-MM-DD) and inclusive; omit both for no date filter.
 */
export class OpsDateRangeQueryDto {
  @ApiPropertyOptional({ description: 'First Vietnam business day, inclusive (YYYY-MM-DD)' })
  @IsOptional()
  @Matches(DAY_KEY)
  from?: string;

  @ApiPropertyOptional({ description: 'Last Vietnam business day, inclusive (YYYY-MM-DD)' })
  @IsOptional()
  @Matches(DAY_KEY)
  to?: string;
}

/**
 * Converts optional `from` / `to` Vietnam business days to a UTC window. Returns undefined when
 * neither bound is set; throws 400 DATE_RANGE_INVALID for an impossible day or `from` after `to`.
 */
export function opsDateWindow(input: {
  from?: string | null;
  to?: string | null;
}): OpsDateWindow | undefined {
  const from = input.from?.trim() || null;
  const to = input.to?.trim() || null;
  if (!from && !to) {
    return undefined;
  }
  const start = from ? startOfHoChiMinhDay(from) : null;
  const lastStart = to ? startOfHoChiMinhDay(to) : null;
  if ((from && !start) || (to && !lastStart) || (start && lastStart && lastStart < start)) {
    throw new BadRequestException({
      message: 'from/to must be valid YYYY-MM-DD days and from ≤ to',
      errorCode: 'DATE_RANGE_INVALID',
    });
  }
  return {
    ...(start ? { start } : {}),
    ...(lastStart ? { end: new Date(lastStart.getTime() + DAY_MS) } : {}),
  };
}

/** Prisma `DateTime` filter for a window; undefined when the window is open on both sides. */
export function prismaDateFilter(
  window: OpsDateWindow | undefined,
): { gte?: Date; lt?: Date } | undefined {
  if (!window || (!window.start && !window.end)) {
    return undefined;
  }
  return {
    ...(window.start ? { gte: window.start } : {}),
    ...(window.end ? { lt: window.end } : {}),
  };
}

/** True when `at` falls inside the window (open bounds always match). */
export function inDateWindow(at: Date, window: OpsDateWindow | undefined): boolean {
  if (!window) return true;
  if (window.start && at < window.start) return false;
  if (window.end && at >= window.end) return false;
  return true;
}

/** Same window as Vietnam day keys, for data already grouped by business day. */
export function dayKeyInWindow(
  day: string,
  input: { from?: string | null; to?: string | null },
): boolean {
  const from = input.from?.trim();
  const to = input.to?.trim();
  if (from && day < from) return false;
  if (to && day > to) return false;
  return true;
}
