"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchReportsData } from "./api";
import type { ReportsFilterParams } from "./types";

export const reportsQueryKeys = {
  all: ["reports"] as const,
  snapshot: (filters?: ReportsFilterParams) =>
    [...reportsQueryKeys.all, "snapshot", filters] as const,
};

export function useReportsQuery(filters?: ReportsFilterParams) {
  return useQuery({
    queryKey: reportsQueryKeys.snapshot(filters),
    queryFn: () => fetchReportsData(filters),
  });
}
