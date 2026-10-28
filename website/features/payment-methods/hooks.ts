"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchPaymentMethods, patchPaymentMethods } from "@/features/payment-methods/api";

export const paymentMethodsQueryKey = ["ops", "payment-methods"] as const;

export function usePaymentMethodsQuery() {
  return useQuery({ queryKey: paymentMethodsQueryKey, queryFn: fetchPaymentMethods });
}

export function usePatchPaymentMethodsMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: patchPaymentMethods,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: paymentMethodsQueryKey }),
  });
}
