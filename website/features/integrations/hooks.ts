"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchEmailSettings,
  fetchMapKeys,
  saveEmailSettings,
  saveMapKeys,
  sendTestEmail,
  testMapKeys,
} from "@/features/integrations/api";
import { mapsProvidersQueryKeys } from "@/features/maps-providers/hooks";

export const integrationsQueryKeys = {
  email: ["integrations", "email"] as const,
  maps: ["integrations", "maps"] as const,
};

export function useEmailSettingsQuery() {
  return useQuery({ queryKey: integrationsQueryKeys.email, queryFn: fetchEmailSettings });
}

export function useSaveEmailSettingsMutation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: saveEmailSettings,
    onSuccess: (view) => qc.setQueryData(integrationsQueryKeys.email, view),
  });
}

export function useSendTestEmailMutation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: sendTestEmail,
    onSuccess: (result) => qc.setQueryData(integrationsQueryKeys.email, result.view),
  });
}

export function useMapKeysQuery() {
  return useQuery({ queryKey: integrationsQueryKeys.maps, queryFn: fetchMapKeys });
}

export function useSaveMapKeysMutation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: saveMapKeys,
    onSuccess: (view) => {
      qc.setQueryData(integrationsQueryKeys.maps, view);
      void qc.invalidateQueries({ queryKey: mapsProvidersQueryKeys.all });
    },
  });
}

export function useTestMapKeysMutation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: testMapKeys,
    onSuccess: (result) => qc.setQueryData(integrationsQueryKeys.maps, result.view),
  });
}
