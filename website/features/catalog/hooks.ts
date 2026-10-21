"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchCatalogCategories,
  renameCatalogCategory,
  type FetchCatalogCategoriesParams,
} from "@/features/catalog/api";

export const catalogQueryKeys = {
  all: ["ops", "catalog-categories"] as const,
  list: (params: FetchCatalogCategoriesParams) =>
    [
      ...catalogQueryKeys.all,
      params.q ?? "",
      params.sort ?? "STORES",
      params.status ?? "",
      params.page ?? 1,
      params.limit ?? 10,
    ] as const,
};

export function useCatalogCategoriesQuery(
  params: FetchCatalogCategoriesParams,
) {
  return useQuery({
    queryKey: catalogQueryKeys.list(params),
    queryFn: () => fetchCatalogCategories(params),
  });
}

export function useRenameCatalogCategoryMutation() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ code, name }: { code: string; name: string }) =>
      renameCatalogCategory(code, name),
    onSuccess: () => {
      void client.invalidateQueries({ queryKey: catalogQueryKeys.all });
    },
  });
}
