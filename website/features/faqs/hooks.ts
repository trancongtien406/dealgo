"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchFaqs, patchFaq } from "@/features/faqs/api";
import type { FaqCategory, FaqStatus } from "@/features/faqs/types";

const queryKey = ["ops", "faqs"] as const;

export function useFaqsQuery(status?: FaqStatus) {
  return useQuery({
    queryKey: [...queryKey, status ?? "all"],
    queryFn: () => fetchFaqs(status),
  });
}

export function usePatchFaqMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      id: string;
      question?: string;
      suggestedAnswer?: string;
      status?: FaqStatus;
      category?: FaqCategory;
      reason: string;
    }) => {
      const { id, ...rest } = input;
      return patchFaq(id, rest);
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey });
    },
  });
}
