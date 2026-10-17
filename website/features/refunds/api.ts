import type { RefundRequest } from "@/features/refunds/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";

export type FetchRefundsParams = ListQuery & {
  status?: string | null;
};

export async function fetchRefunds(
  params: FetchRefundsParams,
): Promise<PaginatedList<RefundRequest>> {
  const search = new URLSearchParams();
  search.set("page", String(Math.max(1, params.page)));
  search.set("limit", String(Math.max(1, params.limit)));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.status && params.status !== "ALL")
    search.set("status", params.status);

  const envelope = await apiFetch<{
    success: boolean;
    data: PaginatedList<RefundRequest>;
  }>(`${apiPaths.opsRefunds()}?${search.toString()}`);
  return envelope.data;
}
