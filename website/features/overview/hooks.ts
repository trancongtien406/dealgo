"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchOverview } from "@/features/overview/api";

export const overviewQueryKeys = {
  all: ["overview"] as const,
  snapshot: () => [...overviewQueryKeys.all, "snapshot"] as const,
};

export function useOverviewQuery() {
  return useQuery({
    queryKey: overviewQueryKeys.snapshot(),
    queryFn: () => fetchOverview(),
    retry: 1,
    // Nest serves stale-while-revalidate; avoid forcing a cold rebuild every mount.
    staleTime: 30_000,
    refetchOnMount: true,
  });
}
