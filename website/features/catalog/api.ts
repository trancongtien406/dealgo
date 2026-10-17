import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import type { CatalogCategory } from "@/features/catalog/types";
import { registerCatalogCategories } from "@/lib/category-labels";

export type FetchCatalogCategoriesParams = ListQuery & {
  sort?: string | null;
  status?: string | null;
};

export type FetchCatalogCategoriesResponse = PaginatedList<CatalogCategory> & {
  totals: {
    categories: number;
    stores: number;
    items: number;
  };
};

export async function fetchCatalogCategories(
  params: FetchCatalogCategoriesParams,
): Promise<FetchCatalogCategoriesResponse> {
  const search = new URLSearchParams();
  if (params.page) search.set("page", String(params.page));
  if (params.limit) search.set("limit", String(params.limit));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.sort) search.set("sort", params.sort);
  if (params.status) search.set("status", params.status);

  const res = await apiFetch<{
    success: boolean;
    data: FetchCatalogCategoriesResponse;
  }>(`${apiPaths.opsCatalogCategories()}?${search.toString()}`);

  if (res.data?.items) {
    registerCatalogCategories(res.data.items);
  }

  return res.data;
}
