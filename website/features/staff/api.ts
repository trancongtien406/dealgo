import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import { parseRbacMatrix, type RbacMatrix } from "@/features/staff/rbac-matrix";

export type PersonItem = {
  id: string;
  roleCode: string;
  superAdmin: boolean;
  name: string;
  email: string;
  letters: string;
  role: string;
  scope: string;
  status: "ACTIVE" | "INVITED" | "SUSPENDED";
  seen: string;
};

export type StaffStatusCounts = {
  active: number;
  pending: number;
  suspended: number;
};

export type StaffPage = PaginatedList<PersonItem> & {
  counts?: StaffStatusCounts;
};

export type FetchStaffParams = ListQuery & {
  role?: string | null;
  status?: string | null;
  scope?: string | null;
};

export type RoleGrantStatus = "PENDING" | "ACTIVE" | "SUSPENDED";

export type OpsRoleGrant = {
  id: string;
  role: string;
  status: RoleGrantStatus;
  userId: string;
  displayName: string;
  phone: string | null;
  email: string | null;
  createdAt: string;
};

export type FetchRoleGrantsParams = {
  status?: RoleGrantStatus | null;
  page?: number;
  limit?: number;
};

export async function fetchStaff(params: FetchStaffParams): Promise<StaffPage> {
  const search = new URLSearchParams();
  if (params.page) search.set("page", String(params.page));
  if (params.limit) search.set("limit", String(params.limit));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.role && params.role !== "ALL") search.set("role", params.role);
  if (params.status && params.status !== "ALL")
    search.set("status", params.status);
  if (params.scope && params.scope !== "ALL") search.set("scope", params.scope);

  const res = await apiFetch<{
    success: boolean;
    data: StaffPage;
  }>(`${apiPaths.opsStaff()}?${search.toString()}`);

  return res.data;
}

export async function fetchRoleGrants(
  params: FetchRoleGrantsParams = {},
): Promise<PaginatedList<OpsRoleGrant>> {
  const search = new URLSearchParams();
  search.set("status", params.status ?? "PENDING");
  if (params.page) search.set("page", String(params.page));
  if (params.limit) search.set("limit", String(params.limit));

  const res = await apiFetch<{
    success: boolean;
    data: PaginatedList<OpsRoleGrant>;
  }>(`${apiPaths.opsRoleGrants()}?${search.toString()}`);

  return {
    items: res.data.items ?? [],
    total: res.data.total ?? 0,
    page: res.data.page ?? params.page ?? 1,
    limit: res.data.limit ?? params.limit ?? 20,
  };
}

export async function approveRoleGrant(id: string): Promise<OpsRoleGrant> {
  const res = await apiFetch<{
    success: boolean;
    data: Pick<OpsRoleGrant, "id" | "role" | "status">;
  }>(apiPaths.opsRoleGrantApprove(id), { method: "POST", body: {} });
  return {
    id: res.data.id,
    role: res.data.role,
    status: res.data.status,
    userId: "",
    displayName: "",
    phone: null,
    email: null,
    createdAt: "",
  };
}

export async function rejectRoleGrant(id: string): Promise<OpsRoleGrant> {
  const res = await apiFetch<{
    success: boolean;
    data: Pick<OpsRoleGrant, "id" | "role" | "status">;
  }>(apiPaths.opsRoleGrantReject(id), { method: "POST", body: {} });
  return {
    id: res.data.id,
    role: res.data.role,
    status: res.data.status,
    userId: "",
    displayName: "",
    phone: null,
    email: null,
    createdAt: "",
  };
}

/** DEC-PROD-045: role → permission matrix from Nest (no static copy). */
export async function fetchRbacMatrix(): Promise<RbacMatrix> {
  const res = await apiFetch<{ success: boolean; data: unknown }>(apiPaths.opsStaffRbacMatrix());
  return parseRbacMatrix(res.data);
}

export type StaffSelf = { id: string; superAdmin: boolean };

export async function fetchStaffMe(): Promise<StaffSelf> {
  const res = await apiFetch<{ success: boolean; data: StaffSelf }>(
    apiPaths.opsStaffMe(),
  );
  return { id: res.data.id, superAdmin: res.data.superAdmin === true };
}

export async function resetStaffPassword(
  id: string,
  body: { newPassword: string; reason: string },
): Promise<{ userId: string; sessionsRevoked: boolean }> {
  const res = await apiFetch<{
    success: boolean;
    data: { userId: string; sessionsRevoked: boolean };
  }>(apiPaths.opsStaffPasswordReset(id), { method: "POST", body });
  return res.data;
}

export async function setStaffSuperAdmin(
  id: string,
  body: { superAdmin: boolean; reason: string },
): Promise<{ userId: string; superAdmin: boolean }> {
  const res = await apiFetch<{
    success: boolean;
    data: { userId: string; superAdmin: boolean };
  }>(apiPaths.opsStaffSuperAdmin(id), { method: "POST", body });
  return res.data;
}

export type StaffAuditLogItem = {
  time: string;
  actor: string;
  action: string;
  target: string;
  status: string;
};

export async function fetchStaffAuditLogs(): Promise<StaffAuditLogItem[]> {
  try {
    const res = await apiFetch<{
      success: boolean;
      data: {
        items: Array<{
          time: string;
          actor: string;
          action: string;
          target: string;
          result: string;
        }>;
      };
    }>(`${apiPaths.opsAuditLogs()}?limit=20`);
    return (res.data?.items ?? []).map((i) => ({
      time: i.time,
      actor: i.actor,
      action: i.action,
      target: i.target,
      status:
        i.result === "SUCCESS"
          ? "Thành công"
          : i.result === "REJECTED"
            ? "Từ chối"
            : "Đã ghi log",
    }));
  } catch {
    return [];
  }
}


export async function setStaffRole(
  id: string,
  body: { staffRole: string; reason: string },
): Promise<{ userId: string; staffRole: string }> {
  const res = await apiFetch<{
    success: boolean;
    data: { userId: string; staffRole: string };
  }>(apiPaths.opsStaffRole(id), { method: "POST", body });
  return res.data;
}
