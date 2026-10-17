import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { PaginatedList } from "@/lib/api/pagination";

export type CampaignItem = {
  code: string;
  voucher: string;
  name: string;
  condition: string;
  service: string;
  window: string;
  status: string;
  used: number;
  cap: number;
  owner: string;
};

export type FetchPromotionsParams = {
  page?: number;
  limit?: number;
  q?: string;
  status?: string | null;
  channel?: string | null;
  audience?: string | null;
};

export async function fetchPromotions(
  params: FetchPromotionsParams,
): Promise<PaginatedList<CampaignItem>> {
  const search = new URLSearchParams();
  search.set("page", String(Math.max(1, params.page ?? 1)));
  search.set("limit", String(Math.max(1, params.limit ?? 10)));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.status && params.status !== "ALL")
    search.set("status", params.status);
  if (params.channel && params.channel !== "ALL") {
    search.set("channel", params.channel);
  }
  if (params.audience && params.audience !== "ALL") {
    search.set("audience", params.audience);
  }

  const envelope = await apiFetch<{
    success: boolean;
    data: PaginatedList<CampaignItem>;
  }>(`${apiPaths.opsPromotions()}?${search.toString()}`);
  return envelope.data;
}
