import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { AuditResult } from "@/features/settings/types";

export type AuditLogItem = {
  id: string;
  code: string;
  time: string;
  createdAt: string;
  actor: string;
  action: string;
  target: string;
  entityType?: string;
  reason: string;
  result: AuditResult;
};

export type FetchAuditLogsParams = {
  page?: number;
  limit?: number;
  q?: string;
  result?: string | null;
  entityType?: string | null;
};

export async function fetchAuditLogs(params: FetchAuditLogsParams): Promise<{
  items: AuditLogItem[];
  total: number;
}> {
  const query = new URLSearchParams();
  if (params.page) query.set("page", String(params.page));
  if (params.limit) query.set("limit", String(params.limit));
  if (params.q?.trim()) query.set("q", params.q.trim());
  if (params.result) query.set("result", params.result);
  if (params.entityType) query.set("entityType", params.entityType);

  const res = await apiFetch<{
    success: boolean;
    data: {
      items: AuditLogItem[];
      total: number;
    };
  }>(`${apiPaths.opsAuditLogs()}?${query.toString()}`);

  return {
    items: res.data?.items ?? [],
    total: res.data?.total ?? res.data?.items?.length ?? 0,
  };
}
