/** Ops website config: GET/PATCH /v1/ops/site-config via BFF (audited, settings.write). */
import type { PublicSiteConfig } from "@/features/site-config/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchSiteConfig(): Promise<PublicSiteConfig> {
  const envelope = await apiFetch<{ success: boolean; data: PublicSiteConfig }>(apiPaths.opsSiteConfig());
  return envelope.data ?? {};
}

export async function patchSiteConfig(input: { config: PublicSiteConfig; reason: string }): Promise<void> {
  await apiFetch<{ success: boolean }>(apiPaths.opsSiteConfig(), { method: "PATCH", body: input });
}
