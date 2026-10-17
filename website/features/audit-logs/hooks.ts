"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAsString, useQueryStates } from "nuqs";
import {
  fetchAuditLogs,
  type FetchAuditLogsParams,
} from "@/features/audit-logs/api";
import { listSearchParams } from "@/lib/list-search-params";

export const auditLogsQueryKeys = {
  all: ["audit-logs"] as const,
  list: (params: FetchAuditLogsParams) =>
    ["audit-logs", "list", params] as const,
};

export function useAuditLogsFilters() {
  return useQueryStates({
    ...listSearchParams,
    result: parseAsString.withDefault(""),
    entityType: parseAsString.withDefault(""),
  });
}

export function useAuditLogsQuery() {
  const [filters] = useAuditLogsFilters();
  const params: FetchAuditLogsParams = {
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
    result: filters.result || null,
    entityType: filters.entityType || null,
  };
  return useQuery({
    queryKey: auditLogsQueryKeys.list(params),
    queryFn: () => fetchAuditLogs(params),
  });
}
