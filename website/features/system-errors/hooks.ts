"use client";

import {
  keepPreviousData,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { parseAsString, parseAsStringLiteral, useQueryStates } from "nuqs";
import {
  fetchIssue,
  fetchIssues,
  fetchSentrySettings,
  fetchUnresolvedCount,
  saveSentrySettings,
  testSentrySettings,
  updateIssueStatus,
} from "@/features/system-errors/api";
import {
  ISSUE_PERIODS,
  ISSUE_SORTS,
  ISSUE_STATUSES,
  type IssueListParams,
} from "@/features/system-errors/types";
import { ApiError } from "@/lib/api/errors";

export const systemErrorsQueryKeys = {
  all: ["system-errors"] as const,
  list: (params: IssueListParams) => ["system-errors", "list", params] as const,
  detail: (id: string) => ["system-errors", "detail", id] as const,
  count: ["system-errors", "count"] as const,
  settings: ["integrations", "sentry"] as const,
};

/** Sentry rate-limits per token; Nest caches 30s, so client retries only add noise. */
function retryUnlessClientError(failureCount: number, error: unknown): boolean {
  if (error instanceof ApiError && error.status < 500) return false;
  return failureCount < 1;
}

export function useSystemErrorsFilters() {
  return useQueryStates({
    project: parseAsString.withDefault(""),
    environment: parseAsString.withDefault(""),
    status: parseAsStringLiteral(ISSUE_STATUSES).withDefault("unresolved"),
    period: parseAsStringLiteral(ISSUE_PERIODS).withDefault("14d"),
    sort: parseAsStringLiteral(ISSUE_SORTS).withDefault("date"),
    q: parseAsString.withDefault(""),
    cursor: parseAsString.withDefault(""),
    issue: parseAsString.withDefault(""),
  });
}

export function useSystemErrorsQuery() {
  const [filters] = useSystemErrorsFilters();
  const params: IssueListParams = {
    project: filters.project || null,
    environment: filters.environment || null,
    status: filters.status,
    period: filters.period,
    sort: filters.sort,
    q: filters.q,
    cursor: filters.cursor || null,
  };
  return useQuery({
    queryKey: systemErrorsQueryKeys.list(params),
    queryFn: () => fetchIssues(params),
    placeholderData: keepPreviousData,
    retry: retryUnlessClientError,
  });
}

export function useSystemErrorQuery(id: string) {
  return useQuery({
    queryKey: systemErrorsQueryKeys.detail(id),
    queryFn: () => fetchIssue(id),
    enabled: id !== "",
    retry: retryUnlessClientError,
  });
}

/** Unresolved count for the nav badge; silent (no retry) when forbidden or unconfigured. */
export function useSystemErrorsCountQuery() {
  return useQuery({
    queryKey: systemErrorsQueryKeys.count,
    queryFn: fetchUnresolvedCount,
    refetchInterval: 120_000,
    staleTime: 60_000,
    retry: false,
  });
}

export function useUpdateIssueStatusMutation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: updateIssueStatus,
    onSuccess: (detail) => {
      qc.setQueryData(systemErrorsQueryKeys.detail(detail.id), detail);
      void qc.invalidateQueries({ queryKey: systemErrorsQueryKeys.all });
    },
  });
}

export function useSentrySettingsQuery() {
  return useQuery({
    queryKey: systemErrorsQueryKeys.settings,
    queryFn: fetchSentrySettings,
  });
}

export function useSaveSentrySettingsMutation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: saveSentrySettings,
    onSuccess: (view) => {
      qc.setQueryData(systemErrorsQueryKeys.settings, view);
      void qc.invalidateQueries({ queryKey: systemErrorsQueryKeys.all });
    },
  });
}

export function useTestSentrySettingsMutation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: testSentrySettings,
    onSuccess: (result) =>
      qc.setQueryData(systemErrorsQueryKeys.settings, result.view),
  });
}
