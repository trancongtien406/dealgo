"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAsStringLiteral, useQueryStates } from "nuqs";
import { fetchExceptions } from "@/features/exceptions/api";
import { listSearchParams } from "@/lib/list-search-params";

const exceptionStatusFilterValues = [
  "ALL",
  "OPEN",
  "IN_PROGRESS",
  "RESOLVED",
  "ESCALATED",
] as const;

export type ExceptionListFilterStatus =
  (typeof exceptionStatusFilterValues)[number];

export const exceptionQueryKeys = {
  all: ["exceptions"] as const,
  list: (filters: {
    status: ExceptionListFilterStatus;
    q: string;
    page: number;
    limit: number;
  }) => [...exceptionQueryKeys.all, "list", filters] as const,
};

export function useExceptionListFilters() {
  return useQueryStates({
    ...listSearchParams,
    status: parseAsStringLiteral(exceptionStatusFilterValues).withDefault(
      "ALL",
    ),
  });
}

export function useExceptionsQuery() {
  const [filters] = useExceptionListFilters();
  return useQuery({
    queryKey: exceptionQueryKeys.list(filters),
    queryFn: () =>
      fetchExceptions({
        status: filters.status,
        q: filters.q,
        page: filters.page,
        limit: filters.limit,
      }),
  });
}
