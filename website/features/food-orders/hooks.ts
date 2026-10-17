"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { parseAsString, parseAsStringLiteral, useQueryStates } from "nuqs";
import {
  cancelFoodOrder,
  fetchFoodOrderByCode,
  fetchFoodOrders,
  reassignFoodOrder,
} from "@/features/food-orders/api";
import { ledgerQueryKeys } from "@/features/ledger/hooks";
import { listSearchParams } from "@/lib/list-search-params";

const foodOrderStatusFilterValues = [
  "ALL",
  "AWAITING_CONFIRMATION",
  "PREPARING",
  "DELIVERING",
  "COMPLETED",
  "CANCELLED",
] as const;

export type FoodOrderListFilterStatus =
  (typeof foodOrderStatusFilterValues)[number];

export const foodOrderQueryKeys = {
  all: ["food-orders"] as const,
  list: (filters: {
    status: FoodOrderListFilterStatus;
    store?: string | null;
    payment?: string | null;
    zone?: string | null;
    q: string;
    page: number;
    limit: number;
  }) => [...foodOrderQueryKeys.all, "list", filters] as const,
  detail: (code: string) =>
    [...foodOrderQueryKeys.all, "detail", code] as const,
};

export function useFoodOrderListFilters() {
  return useQueryStates({
    ...listSearchParams,
    status: parseAsStringLiteral(foodOrderStatusFilterValues).withDefault(
      "ALL",
    ),
    store: parseAsString.withDefault("ALL"),
    payment: parseAsString.withDefault("ALL"),
    zone: parseAsString.withDefault("ALL"),
  });
}

export function useFoodOrdersQuery() {
  const [filters] = useFoodOrderListFilters();
  const params = {
    status: filters.status,
    store: filters.store === "ALL" ? null : filters.store,
    payment: filters.payment === "ALL" ? null : filters.payment,
    zone: filters.zone === "ALL" ? null : filters.zone,
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
  };
  return useQuery({
    queryKey: foodOrderQueryKeys.list(params),
    queryFn: () => fetchFoodOrders(params),
  });
}

export function useFoodOrderDetailQuery(code: string) {
  return useQuery({
    queryKey: foodOrderQueryKeys.detail(code),
    queryFn: () => fetchFoodOrderByCode(code),
  });
}

export function useCancelFoodOrderMutation(code: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (reason: string) => cancelFoodOrder(code, reason),
    onSuccess: (updated) => {
      queryClient.setQueryData(foodOrderQueryKeys.detail(code), updated);
      void queryClient.invalidateQueries({ queryKey: foodOrderQueryKeys.all });
      void queryClient.invalidateQueries({
        queryKey: ledgerQueryKeys.foodOrder(code),
      });
    },
  });
}

export function useReassignFoodOrderMutation(code: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (reason: string) => reassignFoodOrder(code, reason),
    onSuccess: (updated) => {
      queryClient.setQueryData(foodOrderQueryKeys.detail(code), updated);
      void queryClient.invalidateQueries({ queryKey: foodOrderQueryKeys.all });
    },
  });
}
