/**
 * Ops list date filter: `from` / `to` are inclusive Vietnam business days (YYYY-MM-DD,
 * Asia/Ho_Chi_Minh). The Nest Ops list endpoints (transactions, food orders / deliveries,
 * settlements, catalog moderation) turn them into a server-side window, so the filter covers
 * every page, not just the rows on screen.
 */
export type OpsDateRange = { from?: string | null; to?: string | null };

const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

/** A real calendar day in YYYY-MM-DD form, else null. */
export function opsDayKey(value: string | null | undefined): string | null {
  const v = value?.trim();
  if (!v || !DAY_KEY.test(v)) return null;
  const [y, m, d] = v.split("-").map(Number);
  const probe = new Date(Date.UTC(y, m - 1, d));
  return probe.getUTCFullYear() === y &&
    probe.getUTCMonth() === m - 1 &&
    probe.getUTCDate() === d
    ? v
    : null;
}

/** Valid bounds only, swapped when reversed (the backend answers 400 for from > to). */
export function normalizeOpsDateRange(range: OpsDateRange): {
  from?: string;
  to?: string;
} {
  let from = opsDayKey(range.from);
  let to = opsDayKey(range.to);
  if (from && to && from > to) [from, to] = [to, from];
  return { ...(from ? { from } : {}), ...(to ? { to } : {}) };
}

/** Browser → BFF: adds from/to to a list query. */
export function setOpsDateRange(
  search: URLSearchParams,
  range: OpsDateRange,
): URLSearchParams {
  const { from, to } = normalizeOpsDateRange(range);
  if (from) search.set("from", from);
  if (to) search.set("to", to);
  return search;
}

/** BFF → Nest: reads from/to off the incoming request, dropping invalid values. */
export function opsDateRangeFromSearch(searchParams: URLSearchParams): {
  from?: string;
  to?: string;
} {
  return normalizeOpsDateRange({
    from: searchParams.get("from"),
    to: searchParams.get("to"),
  });
}
