"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  createZone,
  fetchZoneRules,
  fetchZones,
  patchZone,
  type FetchZoneRulesParams,
} from "@/features/zones/api";
import type { CreateZoneInput, PatchZoneInput } from "@/features/zones/types";

export function useZonesQuery(status?: string | null) {
  return useQuery({
    queryKey: ["ops", "zones", status ?? "ACTIVE"],
    queryFn: () => fetchZones(status),
  });
}

export function useCreateZoneMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateZoneInput) => createZone(input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["ops", "zones"] });
      void queryClient.invalidateQueries({ queryKey: ["ops", "zones-rules"] });
      void queryClient.invalidateQueries({ queryKey: ["ops", "overview"] });
    },
  });
}

export function usePatchZoneMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ code, input }: { code: string; input: PatchZoneInput }) =>
      patchZone(code, input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["ops", "zones"] });
      void queryClient.invalidateQueries({ queryKey: ["ops", "zones-rules"] });
      void queryClient.invalidateQueries({ queryKey: ["ops", "overview"] });
    },
  });
}

export function useZoneRulesQuery(params: FetchZoneRulesParams) {
  return useQuery({
    queryKey: [
      "ops",
      "zones-rules",
      params.page ?? 1,
      params.limit ?? 10,
      params.q ?? "",
      params.service ?? "ALL",
      params.status ?? "ALL",
    ],
    queryFn: () => fetchZoneRules(params),
  });
}
