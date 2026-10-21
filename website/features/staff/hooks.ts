"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  approveRoleGrant,
  fetchRbacMatrix,
  fetchRoleGrants,
  fetchStaff,
  fetchStaffAuditLogs,
  fetchStaffMe,
  rejectRoleGrant,
  resetStaffPassword,
  setStaffSuperAdmin,
  setStaffRole,
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

export function useRbacMatrixQuery() {
  return useQuery({
    queryKey: ["ops", "staff", "rbac-matrix"],
    queryFn: () => fetchRbacMatrix(),
    staleTime: 5 * 60_000,
  });
}

export function useStaffMeQuery() {
  return useQuery({
    queryKey: ["ops", "staff", "me"],
    queryFn: () => fetchStaffMe(),
    staleTime: 60_000,
  });
}

export function useResetStaffPasswordMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { id: string; newPassword: string; reason: string }) =>
      resetStaffPassword(input.id, {
        newPassword: input.newPassword,
        reason: input.reason,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: staffAuditLogsQueryKey });
    },
  });
}

/** Grant/revoke super-admin; refreshes the staff list, "me" and the audit log. */
export function useSetStaffSuperAdminMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { id: string; superAdmin: boolean; reason: string }) =>
      setStaffSuperAdmin(input.id, { superAdmin: input.superAdmin, reason: input.reason }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["ops", "staff"] });
      void queryClient.invalidateQueries({ queryKey: staffAuditLogsQueryKey });
    },
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


export function useSetStaffRoleMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { id: string; staffRole: string; reason: string }) =>
      setStaffRole(input.id, { staffRole: input.staffRole, reason: input.reason }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["ops", "staff"] });
      void queryClient.invalidateQueries({ queryKey: staffAuditLogsQueryKey });
    },
  });
}
