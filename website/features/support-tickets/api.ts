import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type {
  SupportTicket,
  SupportTicketPage,
  SupportTicketPriority,
  SupportTicketStatus,
} from "@/features/support-tickets/types";

export type FetchSupportTicketsParams = {
  page: number;
  limit: number;
  q?: string;
  status?: string | null;
  category?: string | null;
  channel?: string | null;
};

type Envelope<T> = { success: boolean; data: T };

export async function fetchSupportTickets(
  params: FetchSupportTicketsParams,
): Promise<SupportTicketPage> {
  const search = new URLSearchParams();
  search.set("page", String(params.page));
  search.set("limit", String(params.limit));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.status) search.set("status", params.status);
  if (params.category) search.set("category", params.category);
  if (params.channel) search.set("channel", params.channel);
  const envelope = await apiFetch<Envelope<SupportTicketPage>>(
    `${apiPaths.opsSupportTickets()}?${search.toString()}`,
  );
  return envelope.data;
}

export async function fetchSupportTicket(id: string): Promise<SupportTicket> {
  const envelope = await apiFetch<Envelope<SupportTicket>>(apiPaths.opsSupportTicket(id));
  return envelope.data;
}

export type PatchSupportTicketInput = {
  status?: SupportTicketStatus;
  priority?: SupportTicketPriority;
  reason: string;
};

export async function patchSupportTicket(
  id: string,
  input: PatchSupportTicketInput,
): Promise<SupportTicket> {
  const envelope = await apiFetch<Envelope<SupportTicket>>(apiPaths.opsSupportTicket(id), {
    method: "PATCH",
    body: input,
  });
  return envelope.data;
}

export async function replySupportTicket(id: string, body: string): Promise<SupportTicket> {
  const envelope = await apiFetch<Envelope<SupportTicket>>(
    apiPaths.opsSupportTicketReplies(id),
    { method: "POST", body: { body } },
  );
  return envelope.data;
}
