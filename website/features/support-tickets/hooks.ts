"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchSupportTicket,
  fetchSupportTickets,
  patchSupportTicket,
  replySupportTicket,
  type FetchSupportTicketsParams,
  type PatchSupportTicketInput,
} from "@/features/support-tickets/api";

export const supportTicketKeys = {
  all: ["ops", "support-tickets"] as const,
  list: (params: FetchSupportTicketsParams) =>
    ["ops", "support-tickets", "list", params] as const,
  detail: (id: string) => ["ops", "support-tickets", "detail", id] as const,
};

export function useSupportTicketsQuery(params: FetchSupportTicketsParams) {
  return useQuery({
    queryKey: supportTicketKeys.list(params),
    queryFn: () => fetchSupportTickets(params),
  });
}

export function useSupportTicketQuery(id: string) {
  return useQuery({
    queryKey: supportTicketKeys.detail(id),
    queryFn: () => fetchSupportTicket(id),
    enabled: Boolean(id),
  });
}

export function usePatchSupportTicketMutation(id: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: PatchSupportTicketInput) => patchSupportTicket(id, input),
    onSuccess: (ticket) => {
      queryClient.setQueryData(supportTicketKeys.detail(id), ticket);
      void queryClient.invalidateQueries({ queryKey: [...supportTicketKeys.all, "list"] });
    },
  });
}

export function useReplySupportTicketMutation(id: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: string) => replySupportTicket(id, body),
    onSuccess: (ticket) => {
      queryClient.setQueryData(supportTicketKeys.detail(id), ticket);
      void queryClient.invalidateQueries({ queryKey: [...supportTicketKeys.all, "list"] });
    },
  });
}
