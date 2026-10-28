import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { PaginatedList } from "@/lib/api/pagination";
import type { StoreReview } from "@/features/reviews/types";

export type FetchReviewsParams = {
  page: number;
  limit: number;
  q?: string;
  visibility?: string | null;
  maxStars?: string | null;
  storeId?: string | null;
};

type NestReviewRow = Partial<StoreReview> & { id: string };

export function mapReview(row: NestReviewRow): StoreReview {
  return {
    id: row.id,
    storeId: row.storeId ?? "",
    storeName: row.storeName?.trim() || "Cửa hàng",
    stars: Math.min(5, Math.max(1, Math.round(row.stars ?? 0))),
    tags: Array.isArray(row.tags) ? row.tags : [],
    comment: row.comment?.trim() ? row.comment : null,
    merchantReply: row.merchantReply?.trim() ? row.merchantReply : null,
    repliedAt: row.repliedAt ?? null,
    createdAt: row.createdAt ?? "",
    hidden: row.hidden === true,
    hiddenAt: row.hiddenAt ?? null,
    hiddenReason: row.hiddenReason ?? null,
  };
}

export function reviewsSearch(params: FetchReviewsParams): URLSearchParams {
  const search = new URLSearchParams();
  search.set("page", String(params.page));
  search.set("limit", String(params.limit));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.visibility === "VISIBLE" || params.visibility === "HIDDEN") {
    search.set("visibility", params.visibility);
  }
  if (params.maxStars && /^[1-5]$/.test(params.maxStars)) {
    search.set("maxStars", params.maxStars);
  }
  if (params.storeId?.trim()) search.set("storeId", params.storeId.trim());
  return search;
}

export async function fetchReviews(
  params: FetchReviewsParams,
): Promise<PaginatedList<StoreReview>> {
  const envelope = await apiFetch<{
    success: boolean;
    data: { items: NestReviewRow[]; total: number; page: number; limit: number };
  }>(`${apiPaths.opsReviews()}?${reviewsSearch(params).toString()}`);
  return {
    items: (envelope.data.items ?? []).map(mapReview),
    total: envelope.data.total,
    page: envelope.data.page,
    limit: envelope.data.limit,
  };
}

export async function setReviewHidden(
  id: string,
  hidden: boolean,
  reason: string,
): Promise<void> {
  await apiFetch(apiPaths.opsReviewVisibility(id), {
    method: "PATCH",
    body: { hidden, reason },
  });
}
