import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import { mapNestReport } from "./mappers";
import type { NestOpsReport, ReportsFilterParams, ReportsSnapshotView } from "./types";

export function reportsSearch(params?: ReportsFilterParams): string {
  const search = new URLSearchParams();
  if (params?.from) search.set("from", params.from);
  if (params?.to) search.set("to", params.to);
  const query = search.toString();
  return query ? `?${query}` : "";
}

/** Period report for the selected Vietnam business-day range (GET /v1/ops/reports). */
export async function fetchReportsData(
  params?: ReportsFilterParams,
): Promise<ReportsSnapshotView> {
  const envelope = await apiFetch<{ success: boolean; data: NestOpsReport }>(
    `${apiPaths.opsReports()}${reportsSearch(params)}`,
  );
  return mapNestReport(envelope.data);
}
