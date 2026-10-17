"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchSettlementLines } from "@/features/settlements/api";

export const settlementQueryKeys = {
  all: ["settlements"] as const,
  lines: (page: number, limit: number) =>
    [...settlementQueryKeys.all, "lines", page, limit] as const,
};

export function useSettlementLinesQuery(page = 1, limit = 20) {
  return useQuery({
    queryKey: settlementQueryKeys.lines(page, limit),
    queryFn: () => fetchSettlementLines({ page, limit }),
  });
}
