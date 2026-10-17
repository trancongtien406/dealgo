import type {
  StoreApproval,
  StoreApprovalStatus,
} from "@/features/store-approvals/types";
import type {
  NestPartnerApplicationList,
  NestPartnerApplicationView,
} from "@/features/kyc/nest-types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import { formatOpsDate } from "@/lib/ops-time";

export type FetchStoreApprovalsParams = ListQuery & {
  status?: string | null;
};

function metaString(
  meta: Record<string, unknown>,
  key: string,
): string | undefined {
  const value = meta[key];
  return typeof value === "string" && value.trim() !== "" ? value : undefined;
}

export function mapNestToStoreApproval(
  app: NestPartnerApplicationView,
): StoreApproval {
  const meta =
    app.metadata && typeof app.metadata === "object"
      ? (app.metadata as Record<string, unknown>)
      : {};
  const name =
    metaString(meta, "storeName") ||
    metaString(meta, "name") ||
    `Cửa hàng ${app.id.slice(0, 8)}`;
  const owner =
    metaString(meta, "ownerName") ||
    metaString(meta, "owner") ||
    "Chủ cửa hàng";
  const words = name.split(/\s+/).filter(Boolean);
  const initials = (
    words.length >= 2 ? words[0][0] + words[1][0] : name.slice(0, 2)
  ).toUpperCase();
  const phone = metaString(meta, "phone");

  let status: StoreApprovalStatus = "PENDING_KYB";
  if (app.status === "APPROVED") status = "APPROVED";
  else if (app.status === "REJECTED") status = "REJECTED";
  else if (app.status === "SUBMITTED") status = "PENDING_KYB";
  else if (app.status === "DRAFT") status = "NEEDS_VERIFY";

  return {
    code: app.id,
    initials,
    name,
    category: metaString(meta, "category") || "Đang cập nhật",
    owner,
    phoneMasked: metaString(meta, "phoneMasked") || phone || "—",
    address: metaString(meta, "address") || "Chưa cập nhật",
    area:
      metaString(meta, "area") || metaString(meta, "city") || "Đang cập nhật",
    registrationType: metaString(meta, "registrationType") || "Chưa cập nhật",
    submittedAt: formatOpsDate(app.submittedAt),
    status,
    saleReady: app.status === "APPROVED",
    assignee: metaString(meta, "assignee") || "Chưa phân công",
  };
}

export async function fetchStoreApprovals(
  params: FetchStoreApprovalsParams,
): Promise<PaginatedList<StoreApproval>> {
  const search = new URLSearchParams();
  search.set("role", "MERCHANT");
  if (params.status && params.status !== "ALL") {
    let nestStatus = "SUBMITTED";
    if (params.status === "APPROVED") nestStatus = "APPROVED";
    if (params.status === "REJECTED") nestStatus = "REJECTED";
    search.set("status", nestStatus);
  } else {
    search.set("status", "SUBMITTED");
  }

  if (params.page) search.set("page", String(params.page));
  if (params.limit) search.set("limit", String(params.limit));
  if (params.q?.trim()) search.set("q", params.q.trim());

  const envelope = await apiFetch<{
    success: boolean;
    data: NestPartnerApplicationList;
  }>(`${apiPaths.opsPartnerApplications()}?${search.toString()}`);

  const total = envelope.data.total ?? envelope.data.applications.length;
  const page = envelope.data.page ?? params.page ?? 1;
  const limit = envelope.data.limit ?? params.limit ?? 10;
  const items = envelope.data.applications.map(mapNestToStoreApproval);

  return {
    items,
    total,
    page,
    limit,
  };
}

export async function approveStoreApplication(
  id: string,
): Promise<StoreApproval> {
  const envelope = await apiFetch<{
    success: boolean;
    data: NestPartnerApplicationView;
  }>(apiPaths.opsPartnerApplicationApprove(id), { method: "POST", body: {} });
  return mapNestToStoreApproval(envelope.data);
}

export async function rejectStoreApplication(
  id: string,
  reason: string,
): Promise<StoreApproval> {
  const envelope = await apiFetch<{
    success: boolean;
    data: NestPartnerApplicationView;
  }>(apiPaths.opsPartnerApplicationReject(id), {
    method: "POST",
    body: { reason },
  });
  return mapNestToStoreApproval(envelope.data);
}
