import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { PaginatedList } from "@/lib/api/pagination";

export type CampaignItem = {
  id: string;
  code: string;
  voucher: string;
  name: string;
  description?: string;
  condition: string;
  service: string;
  serviceType: string;
  discountType: string;
  discountValue: number;
  maxDiscountAmount?: number;
  minOrderAmount: number;
  totalBudget: number;
  usedBudget: number;
  usageLimit: number;
  usedCount: number;
  used: number;
  cap: number;
  window: string;
  startDate: string;
  endDate: string;
  status: string;
  owner: string;
  targetAudience: string;
  createdAt: string;
  /** Set for a merchant-created store offer (applies only at that store). */
  storeId: string | null;
  storeName: string | null;
};

export type PromotionKpiSummary = {
  totalCampaigns: number;
  activeCount: number;
  scheduledCount: number;
  endedCount: number;
  totalBudgetCommitted: number;
  totalBudgetSpent: number;
  totalRedemptions: number;
};

export type FetchPromotionsParams = {
  page?: number;
  limit?: number;
  q?: string;
  status?: string | null;
  channel?: string | null;
  serviceType?: string | null;
  audience?: string | null;
  scope?: string | null;
};

export type PromotionsResponseData = PaginatedList<CampaignItem> & {
  kpi?: PromotionKpiSummary;
};

export async function fetchPromotions(
  params: FetchPromotionsParams,
): Promise<PromotionsResponseData> {
  const search = new URLSearchParams();
  search.set("page", String(Math.max(1, params.page ?? 1)));
  search.set("limit", String(Math.max(1, params.limit ?? 10)));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.status && params.status !== "ALL") {
    search.set("status", params.status);
  }
  if (params.serviceType && params.serviceType !== "ALL") {
    search.set("serviceType", params.serviceType);
  } else if (params.channel && params.channel !== "ALL") {
    search.set("channel", params.channel);
  }
  if (params.audience && params.audience !== "ALL") {
    search.set("audience", params.audience);
  }
  if (params.scope === "STORE" || params.scope === "PLATFORM") {
    search.set("scope", params.scope);
  }

  const envelope = await apiFetch<{
    success: boolean;
    data: PromotionsResponseData;
  }>(`${apiPaths.opsPromotions()}?${search.toString()}`);
  return envelope.data;
}

export type CreatePromotionPayload = {
  code: string;
  name: string;
  description: string;
  serviceType: "ALL" | "RIDE" | "FOOD";
  discountType: "FIXED_AMOUNT" | "PERCENTAGE" | "DELIVERY_DISCOUNT";
  discountValue: number;
  maxDiscountAmount?: number;
  minOrderAmount: number;
  totalBudget: number;
  usageLimit: number;
  userLimit?: number;
  targetAudience?: "ALL" | "CUSTOMER" | "DRIVER" | "MERCHANT";
  startDate: string;
  endDate: string;
  sponsor?: "PLATFORM" | "MERCHANT" | "SHARED";
};

export async function createPromotion(
  payload: CreatePromotionPayload,
): Promise<CampaignItem> {
  const envelope = await apiFetch<{
    success: boolean;
    data: CampaignItem;
  }>(apiPaths.opsPromotions(), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return envelope.data;
}

export async function updatePromotionStatus(
  id: string,
  status: "ACTIVE" | "PAUSED" | "CANCELLED",
  reason?: string,
): Promise<CampaignItem> {
  const envelope = await apiFetch<{
    success: boolean;
    data: CampaignItem;
  }>(apiPaths.opsPromotionStatus(id), {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(reason ? { status, reason } : { status }),
  });
  return envelope.data;
}
