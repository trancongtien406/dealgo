"use client";

import { useQuery } from "@tanstack/react-query";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { AuditResult } from "@/features/settings/types";

import { formatOpsDateTime } from "@/lib/ops-time";

export type AuditEventItem = {
  code: string;
  time: string;
  actor: string;
  action: string;
  target: string;
  result: AuditResult;
};

export function useSettingsAuditQuery(params: {
  page: number;
  limit: number;
  q?: string;
  result?: string | null;
}) {
  return useQuery({
    queryKey: [
      "ops",
      "settings-audit",
      params.page,
      params.limit,
      params.q ?? "",
      params.result ?? "ALL",
    ],
    queryFn: async () => {
      const search = new URLSearchParams();
      search.set("page", String(params.page));
      search.set("limit", String(params.limit));
      if (params.q?.trim()) search.set("q", params.q.trim());
      if (params.result && params.result !== "ALL")
        search.set("result", params.result);

      const res = await apiFetch<{
        success: boolean;
        data: {
          items: Array<{
            code?: string;
            id?: string;
            time?: string;
            createdAt?: string;
            actor?: string;
            actorEmail?: string;
            action?: string;
            target?: string;
            targetEntity?: string;
            result?: AuditResult;
          }>;
          total: number;
        };
      }>(`${apiPaths.opsAuditLogs()}?${search.toString()}`);

      const items: AuditEventItem[] = (res.data.items ?? []).map((row) => ({
        code: row.code || row.id || "AUD-000",
        time: row.time || formatOpsDateTime(row.createdAt),

        actor: row.actor || row.actorEmail || "Admin",
        action: row.action || "Thao tác hệ thống",
        target: row.target || row.targetEntity || "Cấu hình",
        result: row.result || "SUCCESS",
      }));
      return {
        items,
        total: res.data.total ?? items.length,
      };
    },
  });
}
