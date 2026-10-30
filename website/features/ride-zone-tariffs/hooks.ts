"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { deleteZoneTariff, fetchZoneTariffs, putZoneTariff } from "@/features/ride-zone-tariffs/api";

export const zoneTariffQueryKeys = {
  all: ["ride-zone-tariffs"] as const,
};

export function useZoneTariffsQuery() {
  return useQuery({ queryKey: zoneTariffQueryKeys.all, queryFn: fetchZoneTariffs });
}

export function usePutZoneTariffMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: putZoneTariff,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: zoneTariffQueryKeys.all }),
  });
}

export function useDeleteZoneTariffMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: deleteZoneTariff,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: zoneTariffQueryKeys.all }),
  });
}
