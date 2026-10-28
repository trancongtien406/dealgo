"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchPaymentIntent,
  fetchPaymentIntents,
  reconcilePaymentIntents,
  refundPaymentIntent,
} from "@/features/online-payments/api";
import type { IntentListFilter } from "@/features/online-payments/types";

export const paymentIntentsKey = ["ops", "payment-intents"] as const;

export function usePaymentIntentsQuery(filter: IntentListFilter) {
  return useQuery({ queryKey: [...paymentIntentsKey, filter], queryFn: () => fetchPaymentIntents(filter) });
}

export function usePaymentIntentQuery(id: string | null) {
  return useQuery({
    queryKey: [...paymentIntentsKey, "detail", id],
    queryFn: () => fetchPaymentIntent(id!),
    enabled: Boolean(id),
  });
}

export function useRefundPaymentIntentMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: refundPaymentIntent,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: paymentIntentsKey }),
  });
}

export function useReconcilePaymentIntentsMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: reconcilePaymentIntents,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: paymentIntentsKey }),
  });
}
