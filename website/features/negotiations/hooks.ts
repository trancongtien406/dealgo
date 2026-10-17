"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAsString, useQueryStates } from "nuqs";
import {
  fetchNegotiationByCode,
  fetchNegotiations,
  type FetchNegotiationsParams,
} from "@/features/negotiations/api";
import { listSearchParams } from "@/lib/list-search-params";

export const negotiationsQueryKeys = {
  all: ["negotiations"] as const,
  list: (filters: FetchNegotiationsParams) =>
    ["negotiations", "list", filters] as const,
  detail: (code: string) => ["negotiations", "detail", code] as const,
};

export function useNegotiationsFilters() {
  return useQueryStates({
    ...listSearchParams,
    status: parseAsString.withDefault(""),
    region: parseAsString.withDefault(""),
  });
}

export function useNegotiationsQuery() {
  const [filters] = useNegotiationsFilters();
  const params: FetchNegotiationsParams = {
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
    status: filters.status || null,
    region: filters.region || null,
  };
  return useQuery({
    queryKey: negotiationsQueryKeys.list(params),
    queryFn: () => fetchNegotiations(params),
  });
}

export function useNegotiationDetailQuery(code: string) {
  return useQuery({
    queryKey: negotiationsQueryKeys.detail(code),
    queryFn: () => fetchNegotiationByCode(code),
  });
}
