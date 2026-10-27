"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchSettlementLines } from "@/features/settlements/api";
import type { OpsDateRange } from "@/lib/api/ops-date-range";

export const settlementQueryKeys = {
  all: ["settlements"] as const,
  lines: (page: number, limit: number, range: OpsDateRange = {}) =>
    [
      ...settlementQueryKeys.all,
      "lines",
      page,
      limit,
      range.from ?? null,
      range.to ?? null,
    ] as const,
};

export function useSettlementLinesQuery(
  page = 1,
  limit = 20,
  range: OpsDateRange = {},
) {
  return useQuery({
    queryKey: settlementQueryKeys.lines(page, limit, range),
    queryFn: () =>
      fetchSettlementLines({ page, limit, from: range.from, to: range.to }),
  });
}
