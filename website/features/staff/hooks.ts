"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  approveRoleGrant,
  fetchRoleGrants,
  fetchStaff,
  fetchStaffAuditLogs,
  rejectRoleGrant,
  type FetchRoleGrantsParams,
  type FetchStaffParams,
} from "@/features/staff/api";

export const roleGrantsQueryKey = ["ops", "role-grants"] as const;
export const staffAuditLogsQueryKey = ["ops", "staff-audit-logs"] as const;

export function useStaffQuery(params: FetchStaffParams) {
  return useQuery({
    queryKey: [
      "ops",
      "staff",
      params.page ?? 1,
      params.limit ?? 10,
      params.q ?? "",
      params.role ?? "ALL",
      params.status ?? "ALL",
      params.scope ?? "ALL",
    ],
    queryFn: () => fetchStaff(params),
  });
}

export function usePendingRoleGrantsQuery(
  params: FetchRoleGrantsParams = { status: "PENDING", page: 1, limit: 20 },
) {
  return useQuery({
    queryKey: [
      ...roleGrantsQueryKey,
      params.status ?? "PENDING",
      params.page ?? 1,
      params.limit ?? 20,
    ],
    queryFn: () =>
      fetchRoleGrants({
        status: params.status ?? "PENDING",
        page: params.page ?? 1,
        limit: params.limit ?? 20,
      }),
  });
}

export function useStaffAuditLogsQuery() {
  return useQuery({
    queryKey: staffAuditLogsQueryKey,
    queryFn: () => fetchStaffAuditLogs(),
  });
}

export function useApproveRoleGrantMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => approveRoleGrant(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: roleGrantsQueryKey });
      void queryClient.invalidateQueries({ queryKey: ["ops", "staff"] });
      void queryClient.invalidateQueries({ queryKey: staffAuditLogsQueryKey });
    },
  });
}

export function useRejectRoleGrantMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => rejectRoleGrant(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: roleGrantsQueryKey });
      void queryClient.invalidateQueries({ queryKey: ["ops", "staff"] });
      void queryClient.invalidateQueries({ queryKey: staffAuditLogsQueryKey });
    },
  });
}
