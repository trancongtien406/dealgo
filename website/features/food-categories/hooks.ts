"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  createFoodCategory,
  deleteFoodCategory,
  fetchFoodCategories,
  patchFoodCategory,
  reorderFoodCategories,
  uploadFoodCategoryImage,
} from "@/features/food-categories/api";
import type {
  FoodCategoryPayload,
  FoodCategoryRow,
} from "@/features/food-categories/types";

export const foodCategoriesQueryKey = ["ops", "food-categories"] as const;

export function useFoodCategoriesQuery() {
  return useQuery({
    queryKey: foodCategoriesQueryKey,
    queryFn: fetchFoodCategories,
    staleTime: 60_000,
  });
}

function useInvalidate() {
  const queryClient = useQueryClient();
  return () =>
    void queryClient.invalidateQueries({ queryKey: foodCategoriesQueryKey });
}

export function useCreateFoodCategoryMutation() {
  const onSuccess = useInvalidate();
  return useMutation({ mutationFn: createFoodCategory, onSuccess });
}

export function usePatchFoodCategoryMutation() {
  const onSuccess = useInvalidate();
  return useMutation({
    mutationFn: (input: {
      code: string;
      patch: Partial<FoodCategoryPayload> & { imageUrl?: null };
    }) => patchFoodCategory(input.code, input.patch),
    onSuccess,
  });
}

export function useDeleteFoodCategoryMutation() {
  const onSuccess = useInvalidate();
  return useMutation({ mutationFn: deleteFoodCategory, onSuccess });
}

export function useUploadFoodCategoryImageMutation() {
  const onSuccess = useInvalidate();
  return useMutation({
    mutationFn: (input: { code: string; dataUrl: string }) =>
      uploadFoodCategoryImage(input.code, input.dataUrl),
    onSuccess,
  });
}

/** Optimistic: the dragged order shows at once, rolls back on error. */
export function useReorderFoodCategoriesMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: reorderFoodCategories,
    onMutate: async (codes: string[]) => {
      await queryClient.cancelQueries({ queryKey: foodCategoriesQueryKey });
      const previous = queryClient.getQueryData<FoodCategoryRow[]>(
        foodCategoriesQueryKey,
      );
      if (previous) {
        const byCode = new Map(previous.map((row) => [row.code, row]));
        queryClient.setQueryData(
          foodCategoriesQueryKey,
          codes.flatMap((code) => byCode.get(code) ?? []),
        );
      }
      return { previous };
    },
    onError: (_e, _codes, context) => {
      if (context?.previous) {
        queryClient.setQueryData(foodCategoriesQueryKey, context.previous);
      }
    },
    onSuccess: (items) =>
      queryClient.setQueryData(foodCategoriesQueryKey, items),
  });
}
