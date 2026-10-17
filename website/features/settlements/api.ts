import { mapNestSettlementBatchToLine } from "@/features/settlements/mappers";
import type { NestSettlementPage } from "@/features/settlements/nest-types";
import type { SettlementLine } from "@/features/settlements/types";
import { apiFetch } from "@/lib/api/client";
import type { PaginatedList } from "@/lib/api/pagination";
import { apiPaths } from "@/lib/api/paths";

export type FetchSettlementsParams = {
  page?: number;
  limit?: number;
};

export async function fetchSettlementLines(
  params: FetchSettlementsParams = {},
): Promise<PaginatedList<SettlementLine>> {
  return fetchSettlementsFromBff(params);
}

async function fetchSettlementsFromBff(
  params: FetchSettlementsParams,
): Promise<PaginatedList<SettlementLine>> {
  const page = Math.max(1, params.page ?? 1);
  const limit = Math.max(1, Math.min(50, params.limit ?? 20));
  const search = new URLSearchParams({
    page: String(page),
    limit: String(limit),
  });
  const envelope = await apiFetch<{
    success: boolean;
    data: NestSettlementPage;
  }>(`${apiPaths.opsSettlements()}?${search.toString()}`);

  return {
    items: envelope.data.items.map(mapNestSettlementBatchToLine),
    page: envelope.data.page,
    limit: envelope.data.limit,
    total: envelope.data.total,
  };
}
