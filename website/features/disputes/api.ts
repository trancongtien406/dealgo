import { apiFetch } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import { apiPaths } from "@/lib/api/paths";
import type { DisputeCase } from "@/features/disputes/types";
import type { PaginatedList } from "@/lib/api/pagination";

export type FetchDisputesParams = {
  page: number;
  limit: number;
  q?: string;
  status?: string | null;
  priority?: string | null;
  type?: string | null;
  party?: string | null;
};

export async function fetchDisputes(
  params: FetchDisputesParams,
): Promise<PaginatedList<DisputeCase>> {
  const search = new URLSearchParams();
  search.set("page", String(params.page));
  search.set("limit", String(params.limit));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.status && params.status !== "ALL")
    search.set("status", params.status);
  if (params.priority && params.priority !== "ALL")
    search.set("priority", params.priority);
  if (params.type && params.type !== "ALL") search.set("type", params.type);
  if (params.party && params.party !== "ALL") search.set("party", params.party);

  const envelope = await apiFetch<{
    success: boolean;
    data: {
      items: Array<{
        code: string;
        type?: string;
        priority: DisputeCase["priority"];
        status: DisputeCase["status"];
        openedAt?: string;
        orderCode?: string;
        relatedCode?: string;
        assignee?: string;
        reporter?: string;
        summary?: string;
        createdAt?: string;
        parties?: Array<{ role?: string; name?: string }>;
        order?: { service?: string };
      }>;
      total: number;
      page: number;
      limit: number;
    };
  }>(`${apiPaths.opsDisputes()}?${search.toString()}`);

  const data = envelope.data;
  const items: DisputeCase[] = (data.items || []).map((d) => ({
    code: d.code,
    createdAt: d.createdAt ?? d.openedAt ?? "",
    type: d.type ?? "",
    relatedCode: d.relatedCode ?? d.orderCode ?? "",
    reporter:
      d.reporter ??
      d.parties?.find((p) => p.role?.includes("Khách"))?.name ??
      d.parties?.[0]?.name ??
      "Khách hàng",
    summary: d.summary ?? `${d.type ?? ""} - ${d.order?.service ?? ""}`,
    status: d.status,
    priority: d.priority,
    assignee: d.assignee ?? "Chưa phân công",
  }));

  return {
    items,
    total: data.total,
    page: data.page,
    limit: data.limit,
  };
}

export type DisputeDetailView = {
  code: string;
  type: string;
  priority: DisputeCase["priority"];
  status: DisputeCase["status"];
  verifyStatus: string;
  openedAt: string;
  orderCode: string;
  paymentId: string;
  refundCode: string;
  assignee: string;
  slaRemaining: string;
  parties: Array<{ role: string; name: string; initials: string }>;
  timeline: Array<{ at: string; title: string }>;
  messages: Array<{
    from: string;
    at: string;
    body: string;
    internal?: boolean;
  }>;
  order: {
    code: string;
    service: string;
    result: string;
    payment: string;
    total: number;
    refundRequested: number;
  };
  checklist: Array<{ label: string; status: string }>;
};

export async function fetchDisputeByCode(
  code: string,
): Promise<DisputeDetailView | null> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: Partial<DisputeDetailView> & {
        code: string;
        priority: DisputeCase["priority"];
        status: DisputeCase["status"];
        relatedCode?: string;
        createdAt?: string;
        reporter?: string;
        summary?: string;
      };
    }>(apiPaths.opsDispute(code));
    const d = envelope.data;
    return {
      code: d.code,
      type: d.type ?? "",
      priority: d.priority,
      status: d.status,
      verifyStatus: d.verifyStatus ?? d.status,
      openedAt: d.openedAt ?? d.createdAt ?? "",
      orderCode: d.orderCode ?? d.relatedCode ?? "",
      paymentId: d.paymentId ?? "—",
      refundCode: d.refundCode ?? "—",
      assignee: d.assignee ?? "Chưa phân công",
      slaRemaining: d.slaRemaining ?? "—",
      parties: d.parties ?? [],
      timeline: d.timeline ?? [],
      messages: d.messages ?? [],
      order: d.order ?? {
        code: d.orderCode ?? d.relatedCode ?? "",
        service: "—",
        result: "—",
        payment: "—",
        total: 0,
        refundRequested: 0,
      },
      checklist: d.checklist ?? [],
    };
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) {
      return null;
    }
    throw err;
  }
}
