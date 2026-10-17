"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchMonitorSnapshot } from "@/features/monitor/api";

export const monitorQueryKeys = {
  all: ["monitor"] as const,
  snapshot: () => [...monitorQueryKeys.all, "snapshot"] as const,
};

export function useMonitorQuery() {
  return useQuery({
    queryKey: monitorQueryKeys.snapshot(),
    queryFn: () => fetchMonitorSnapshot(),
    retry: 1,
    refetchInterval: 30_000,
    refetchOnMount: "always",
    staleTime: 0,
  });
}
