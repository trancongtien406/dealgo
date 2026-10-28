"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { parseAsString, useQueryStates } from "nuqs";
import {
  fetchReviews,
  setReviewHidden,
  type FetchReviewsParams,
} from "@/features/reviews/api";
import { listSearchParams } from "@/lib/list-search-params";

export const reviewsQueryKeys = {
  all: ["ops-reviews"] as const,
  list: (params: FetchReviewsParams) => ["ops-reviews", "list", params] as const,
};

export function useReviewsFilters() {
  return useQueryStates({
    ...listSearchParams,
    visibility: parseAsString.withDefault(""),
    maxStars: parseAsString.withDefault(""),
    storeId: parseAsString.withDefault(""),
  });
}

export function useReviewsQuery() {
  const [filters] = useReviewsFilters();
  const params: FetchReviewsParams = {
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
    visibility: filters.visibility || null,
    maxStars: filters.maxStars || null,
    storeId: filters.storeId || null,
  };
  return useQuery({
    queryKey: reviewsQueryKeys.list(params),
    queryFn: () => fetchReviews(params),
  });
}

export function useSetReviewHiddenMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { id: string; hidden: boolean; reason: string }) =>
      setReviewHidden(input.id, input.hidden, input.reason),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: reviewsQueryKeys.all });
    },
  });
}
