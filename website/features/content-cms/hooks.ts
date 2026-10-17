"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchCmsDocument,
  fetchSupportConfig,
  resetCmsDocument,
  resetSupportConfig,
  saveCmsDocument,
  saveSupportConfig,
} from "./api";
import type { ContentDocKey, LegalDocument, SupportConfig } from "./types";

export function useCmsDocumentQuery(key: ContentDocKey) {
  return useQuery({
    queryKey: ["ops", "cms-document", key],
    queryFn: () => fetchCmsDocument(key),
  });
}

export function useSaveCmsDocumentMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ doc, reason }: { doc: LegalDocument; reason?: string }) =>
      saveCmsDocument(doc, reason),
    onSuccess: (data) => {
      queryClient.setQueryData(["ops", "cms-document", data.key], data);
      void queryClient.invalidateQueries({
        queryKey: ["ops", "cms-document", data.key],
      });
    },
  });
}

export function useResetCmsDocumentMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (key: ContentDocKey) => resetCmsDocument(key),
    onSuccess: (data) => {
      queryClient.setQueryData(["ops", "cms-document", data.key], data);
      void queryClient.invalidateQueries({
        queryKey: ["ops", "cms-document", data.key],
      });
    },
  });
}

export function useSupportConfigQuery() {
  return useQuery({
    queryKey: ["ops", "cms-support-config"],
    queryFn: () => fetchSupportConfig(),
  });
}

export function useSaveSupportConfigMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      config,
      reason,
    }: {
      config: SupportConfig;
      reason?: string;
    }) => saveSupportConfig(config, reason),
    onSuccess: (data) => {
      queryClient.setQueryData(["ops", "cms-support-config"], data);
      void queryClient.invalidateQueries({
        queryKey: ["ops", "cms-support-config"],
      });
    },
  });
}

export function useResetSupportConfigMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => resetSupportConfig(),
    onSuccess: (data) => {
      queryClient.setQueryData(["ops", "cms-support-config"], data);
      void queryClient.invalidateQueries({
        queryKey: ["ops", "cms-support-config"],
      });
    },
  });
}
