import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import { formatOpsDateTime } from "@/lib/ops-time";
import { setOpsDateRange, type OpsDateRange } from "@/lib/api/ops-date-range";
import type { ModeratedProduct } from "@/features/catalog-moderation/types";
import type { PaginatedList } from "@/lib/api/pagination";

export type FetchCatalogModerationParams = OpsDateRange & {
  page: number;
  limit: number;
  q?: string;
  store?: string | null;
  category?: string | null;
  status?: string | null;
};

type NestModerationRow = Partial<ModeratedProduct> & {
  id?: string;
  code?: string;
};

/** Nest sends the ISO submission time; show it in Vietnam time, keep any legacy label as-is. */
export function formatSubmittedAt(value: string | null | undefined): string {
  if (!value) return "—";
  const formatted = formatOpsDateTime(value);
  return formatted === "—" ? value : formatted;
}

function mapItem(row: NestModerationRow): ModeratedProduct {
  const code = row.code ?? row.id ?? "—";
  return {
    id: row.id ?? code,
    code,
    name: row.name ?? "—",
    category: row.category ?? "—",
    store: row.store ?? "—",
    price: row.price ?? 0,
    submittedAt: formatSubmittedAt(row.submittedAt),
    status: (row.status as ModeratedProduct["status"]) ?? "PENDING",
    nameReady: row.nameReady ?? false,
    imageReady: row.imageReady ?? false,
  };
}

export async function fetchCatalogModeration(
  params: FetchCatalogModerationParams,
): Promise<PaginatedList<ModeratedProduct>> {
  const search = new URLSearchParams();
  search.set("page", String(params.page));
  search.set("limit", String(params.limit));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.store && params.store !== "ALL") search.set("store", params.store);
  if (params.category && params.category !== "ALL")
    search.set("category", params.category);
  if (params.status && params.status !== "ALL")
    search.set("status", params.status);
  setOpsDateRange(search, params);

  const envelope = await apiFetch<{
    success: boolean;
    data: {
      items: NestModerationRow[];
      total: number;
      page: number;
      limit: number;
    };
  }>(`${apiPaths.opsCatalogModeration()}?${search.toString()}`);

  return {
    items: (envelope.data.items || []).map(mapItem),
    total: envelope.data.total,
    page: envelope.data.page,
    limit: envelope.data.limit,
  };
}

export async function approveCatalogItem(id: string): Promise<void> {
  await apiFetch(apiPaths.opsCatalogItemApprove(id), {
    method: "POST",
    body: {},
  });
}

export async function rejectCatalogItem(id: string): Promise<void> {
  await apiFetch(apiPaths.opsCatalogItemReject(id), {
    method: "POST",
    body: {},
  });
}
