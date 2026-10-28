/**
 * Admin › Lỗi hệ thống: Sentry issues read through Nest (the token never leaves the server).
 */
import type {
  IssueListParams,
  IssueStatusUpdate,
  SentryIssueDetail,
  SentryIssuePage,
  SentrySettingsView,
} from "@/features/system-errors/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

type Envelope<T> = { success: boolean; data: T };

export function issueListQuery(params: IssueListParams): string {
  const query = new URLSearchParams();
  if (params.project) query.set("project", params.project);
  if (params.environment) query.set("environment", params.environment);
  query.set("status", params.status);
  query.set("period", params.period);
  query.set("sort", params.sort);
  if (params.q.trim()) query.set("q", params.q.trim());
  if (params.cursor) query.set("cursor", params.cursor);
  return query.toString();
}

export async function fetchIssues(
  params: IssueListParams,
): Promise<SentryIssuePage> {
  return (
    await apiFetch<Envelope<SentryIssuePage>>(
      `${apiPaths.opsSystemErrors()}?${issueListQuery(params)}`,
    )
  ).data;
}

export async function fetchIssue(id: string): Promise<SentryIssueDetail> {
  return (
    await apiFetch<Envelope<SentryIssueDetail>>(apiPaths.opsSystemError(id))
  ).data;
}

export async function fetchUnresolvedCount(): Promise<{
  count: number | null;
}> {
  return (
    await apiFetch<Envelope<{ count: number | null }>>(
      apiPaths.opsSystemErrorsCount(),
    )
  ).data;
}

export async function updateIssueStatus(input: {
  id: string;
  status: IssueStatusUpdate;
  reason: string;
}): Promise<SentryIssueDetail> {
  return (
    await apiFetch<Envelope<SentryIssueDetail>>(
      apiPaths.opsSystemErrorStatus(input.id),
      {
        method: "PUT",
        body: { status: input.status, reason: input.reason },
      },
    )
  ).data;
}

export async function fetchSentrySettings(): Promise<SentrySettingsView> {
  return (
    await apiFetch<Envelope<SentrySettingsView>>(apiPaths.opsSentrySettings())
  ).data;
}

export async function saveSentrySettings(
  body: Record<string, string | null> & { reason: string },
): Promise<SentrySettingsView> {
  return (
    await apiFetch<Envelope<SentrySettingsView>>(apiPaths.opsSentrySettings(), {
      method: "PUT",
      body,
    })
  ).data;
}

export async function testSentrySettings(
  reason: string,
): Promise<{ ok: boolean; detail: string; view: SentrySettingsView }> {
  return (
    await apiFetch<
      Envelope<{ ok: boolean; detail: string; view: SentrySettingsView }>
    >(apiPaths.opsSentryTest(), { method: "POST", body: { reason } })
  ).data;
}
