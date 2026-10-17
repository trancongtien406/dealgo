"use client";

import { useQuery } from "@tanstack/react-query";
import {
  fetchCatalogCategories,
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
