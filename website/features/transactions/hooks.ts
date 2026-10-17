"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAsString, parseAsStringLiteral, useQueryStates } from "nuqs";
import { fetchTransactions } from "@/features/transactions/api";
import { listSearchParams } from "@/lib/list-search-params";

const txStatusFilterValues = [
  "ALL",
  "COLLECTED",
  "COD_PENDING",
  "COD_CONFIRMED",
  "PROCESSING",
  "FAILED",
] as const;

export type TransactionListFilterStatus = (typeof txStatusFilterValues)[number];

export const transactionQueryKeys = {
  all: ["transactions"] as const,
  list: (filters: {
    status: TransactionListFilterStatus;
    service?: string;
    payment?: string;
    q: string;
    page: number;
    limit: number;
  }) => [...transactionQueryKeys.all, "list", filters] as const,
};

export function useTransactionListFilters() {
  return useQueryStates({
    ...listSearchParams,
    status: parseAsStringLiteral(txStatusFilterValues).withDefault("ALL"),
    service: parseAsString.withDefault("ALL"),
    payment: parseAsString.withDefault("ALL"),
  });
}

export function useTransactionsQuery() {
  const [filters] = useTransactionListFilters();
  return useQuery({
    queryKey: transactionQueryKeys.list(filters),
    queryFn: () =>
      fetchTransactions({
        status: filters.status,
        service: filters.service === "ALL" ? null : filters.service,
        payment: filters.payment === "ALL" ? null : filters.payment,
        q: filters.q,
        page: filters.page,
        limit: filters.limit,
      }),
  });
}
