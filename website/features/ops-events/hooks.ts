"use client";

import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { monitorQueryKeys } from "@/features/monitor/hooks";
import { systemErrorsQueryKeys } from "@/features/system-errors/hooks";
import { openOpsEventStream } from "@/features/ops-events/ops-event-stream";

/**
 * One admin SSE stream per page (mounted in AdminNav). Hints invalidate the REST
 * queries; only queries with an active observer actually refetch.
 */
export function useOpsEventStream(enabled = true) {
  const queryClient = useQueryClient();
  useEffect(() => {
    if (!enabled || typeof EventSource === "undefined") return;
    const monitor = () =>
      void queryClient.invalidateQueries({ queryKey: monitorQueryKeys.all });
    const errors = () =>
      void queryClient.invalidateQueries({ queryKey: systemErrorsQueryKeys.all });
    return openOpsEventStream({
      onMonitor: monitor,
      onSystemErrors: errors,
      onReconnect: () => {
        monitor();
        errors();
      },
    });
  }, [enabled, queryClient]);
}
