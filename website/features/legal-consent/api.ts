/** Ops legal consent versions via BFF (content.write). */
import type { LegalPolicyVersion, PublishLegalVersionInput } from "@/features/legal-consent/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

type Envelope<T> = { success: boolean; data: T };

export async function fetchLegalVersions(): Promise<LegalPolicyVersion[]> {
  return (await apiFetch<Envelope<LegalPolicyVersion[]>>(apiPaths.opsLegalVersions())).data ?? [];
}

export async function publishLegalVersion(input: PublishLegalVersionInput): Promise<LegalPolicyVersion> {
  return (await apiFetch<Envelope<LegalPolicyVersion>>(apiPaths.opsLegalVersions(), { method: "POST", body: input })).data;
}

export async function previewLegalEmail(id: string): Promise<{ recipients: number }> {
  return (await apiFetch<Envelope<{ recipients: number }>>(apiPaths.opsLegalVersionEmailPreview(id))).data;
}

export async function sendLegalEmail(input: { id: string; confirmCount: number }): Promise<LegalPolicyVersion> {
  return (
    await apiFetch<Envelope<LegalPolicyVersion>>(apiPaths.opsLegalVersionEmail(input.id), {
      method: "POST",
      body: { confirmCount: input.confirmCount },
    })
  ).data;
}
