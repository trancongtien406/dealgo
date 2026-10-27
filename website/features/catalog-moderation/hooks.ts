"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { parseAsString, useQueryStates } from "nuqs";
import {
  approveCatalogItem,
  fetchCatalogModeration,
  rejectCatalogItem,
  type FetchCatalogModerationParams,
} from "@/features/catalog-moderation/api";
import {
  dateRangeSearchParams,
  listSearchParams,
} from "@/lib/list-search-params";

export const catalogModerationQueryKeys = {
  all: ["catalog-moderation"] as const,
  list: (params: FetchCatalogModerationParams) =>
    ["catalog-moderation", "list", params] as const,
};

export function useCatalogModerationFilters() {
  return useQueryStates({
    ...listSearchParams,
    ...dateRangeSearchParams,
    category: parseAsString.withDefault(""),
    status: parseAsString.withDefault("PENDING"),
  });
}

export function useCatalogModerationQuery() {
  const [filters] = useCatalogModerationFilters();
  const params: FetchCatalogModerationParams = {
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
    category: filters.category || null,
    status: filters.status || null,
    from: filters.from || null,
    to: filters.to || null,
  };
  return useQuery({
    queryKey: catalogModerationQueryKeys.list(params),
    queryFn: () => fetchCatalogModeration(params),
  });
}

export function useApproveCatalogItemMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => approveCatalogItem(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: catalogModerationQueryKeys.all,
      });
    },
  });
}

export function useRejectCatalogItemMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => rejectCatalogItem(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: catalogModerationQueryKeys.all,
      });
    },
  });
}
