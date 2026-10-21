import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import type {
  CmsItem,
  NotificationCampaignStatus,
} from "@/features/notifications/types";

export type CampaignItem = {
  code: string;
  title: string;
  channel: string;
  audience: string;
  status: NotificationCampaignStatus;
  reached: string;
  schedule: string;
  scheduleNote?: string;
  body?: string;
};

export type FetchNotificationsParams = ListQuery & {
  tab?: string | null;
  channel?: string | null;
  audience?: string | null;
};

export type NotificationCounts = {
  all: number;
  running: number;
  sent: number;
  pending: number;
  draft: number;
};

export type NotificationsPage = PaginatedList<CampaignItem> & {
  counts: NotificationCounts;
};

export type NotificationTabKey =
  "ALL" | "RUNNING" | "SENT" | "PENDING" | "DRAFT";

export async function fetchNotifications(
  params: FetchNotificationsParams,
): Promise<NotificationsPage> {
  const search = new URLSearchParams();
  if (params.page) search.set("page", String(params.page));
  if (params.limit) search.set("limit", String(params.limit));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.tab) search.set("tab", params.tab);
  if (params.channel && params.channel !== "ALL")
    search.set("channel", params.channel);
  if (params.audience && params.audience !== "ALL")
    search.set("audience", params.audience);

  const query = search.toString();
  const res = await apiFetch<{
    success: boolean;
    data: NotificationsPage;
  }>(`${apiPaths.opsNotifications()}${query ? `?${query}` : ""}`);

  return res.data;
}

export type FetchCmsParams = {
  kind?: string | null;
  tab?: string | null;
  q?: string | null;
};

export async function fetchCmsItems(
  params: FetchCmsParams = {},
): Promise<{ items: CmsItem[]; total: number }> {
  const search = new URLSearchParams();
  const targetKind = params.kind ?? params.tab ?? "Tất cả";
  if (targetKind && targetKind !== "Tất cả" && targetKind !== "ALL") {
    search.set("kind", targetKind);
  }
  if (params.q?.trim()) {
    search.set("q", params.q.trim());
  }

  const query = search.toString();
  const res = await apiFetch<{
    success: boolean;
    data: { items: CmsItem[]; total: number };
  }>(`${apiPaths.opsNotificationsCms()}${query ? `?${query}` : ""}`);

  return res.data;
}

export type CreateNotificationCampaignInput = {
  title: string;
  body: string;
  channels: Array<"PUSH" | "SMS" | "EMAIL" | "IN_APP">;
  audience: "ALL" | "CUSTOMER" | "DRIVER" | "MERCHANT" | "STAFF";
  audienceNote?: string | null;
  isAutomatic?: boolean;
  scheduledAt?: string | null;
  reason?: string;
};

export async function createNotificationCampaign(
  input: CreateNotificationCampaignInput,
): Promise<CampaignItem> {
  const res = await apiFetch<{
    success: boolean;
    data: CampaignItem;
  }>(apiPaths.opsNotifications(), {
    method: "POST",
    body: input,
  });
  return res.data;
}

export async function approveNotificationCampaign(
  code: string,
  reason: string,
): Promise<void> {
  await apiFetch(apiPaths.opsNotificationApprove(code), {
    method: "POST",
    body: { reason },
  });
}

export async function rejectNotificationCampaign(
  code: string,
  reason: string,
): Promise<void> {
  await apiFetch(apiPaths.opsNotificationReject(code), {
    method: "POST",
    body: { reason },
  });
}

/** DRAFT → PENDING_APPROVAL (reason optional). */
export async function submitNotificationCampaign(
  code: string,
  reason?: string,
): Promise<void> {
  await apiFetch(apiPaths.opsNotificationSubmit(code), {
    method: "POST",
    body: reason ? { reason } : {},
  });
}

/** DRAFT | PENDING_APPROVAL | RUNNING → CANCELLED (reason required, audited). */
export async function cancelNotificationCampaign(
  code: string,
  reason: string,
): Promise<void> {
  await apiFetch(apiPaths.opsNotificationCancel(code), {
    method: "POST",
    body: { reason },
  });
}

export async function updateNotificationCampaign(
  code: string,
  body: Record<string, unknown>,
): Promise<void> {
  await apiFetch(apiPaths.opsNotificationCampaign(code), {
    method: "PATCH",
    body,
  });
}

export async function patchCmsItem(
  id: string,
  body: Record<string, unknown>,
): Promise<void> {
  await apiFetch(apiPaths.opsNotificationCmsItem(id), {
    method: "PATCH",
    body,
  });
}
