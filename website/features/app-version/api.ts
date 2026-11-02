/** Ops app update policy: GET/PATCH /v1/ops/app-version-policy via BFF (audited, settings.write). */
import type { AppVersionPolicy } from "@/features/app-version/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchAppVersionPolicy(): Promise<AppVersionPolicy> {
  const res = await apiFetch<{ success: boolean; data: AppVersionPolicy }>(apiPaths.opsAppVersionPolicy());
  return res.data;
}

export async function patchAppVersionPolicy(input: { policy: AppVersionPolicy; reason: string }): Promise<void> {
  await apiFetch<{ success: boolean }>(apiPaths.opsAppVersionPolicy(), { method: "PATCH", body: input });
}
