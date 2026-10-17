/**
 * Status KPI for paginated lists when Nest does not return facet `counts`.
 * Prefer API `total` when the active status filter matches the KPI bucket.
 */
export function filteredStatusKpi(args: {
  statusFilter: string | null | undefined;
  targetStatus: string | readonly string[];
  total: number;
  pageCount: number;
}): { value: number; note: string } {
  const targets = Array.isArray(args.targetStatus)
    ? args.targetStatus
    : [args.targetStatus];
  const active =
    args.statusFilter && args.statusFilter !== "ALL" ? args.statusFilter : null;

  if (active && targets.includes(active)) {
    return { value: args.total, note: "theo bộ lọc" };
  }
  if (active && !targets.includes(active)) {
    return { value: 0, note: "ngoài bộ lọc trạng thái" };
  }
  return { value: args.pageCount, note: "trên trang hiện tại" };
}
