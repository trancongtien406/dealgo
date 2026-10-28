/**
 * Ops integrations: email provider + map keys (Nest /v1/ops/integrations/*).
 * Every write carries an audit reason; secrets are write-only.
 */
import type {
  EmailSettingsView,
  EmailTestResult,
  MapKeyField,
  MapKeysView,
  MapKeyTestResult,
} from "@/features/integrations/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

type Envelope<T> = { success: boolean; data: T };

export async function fetchEmailSettings(): Promise<EmailSettingsView> {
  return (await apiFetch<Envelope<EmailSettingsView>>(apiPaths.opsEmailSettings())).data;
}

export async function saveEmailSettings(
  body: Record<string, string | null>,
): Promise<EmailSettingsView> {
  return (
    await apiFetch<Envelope<EmailSettingsView>>(apiPaths.opsEmailSettings(), {
      method: "PUT",
      body,
    })
  ).data;
}

export async function sendTestEmail(input: { to: string; reason: string }): Promise<EmailTestResult> {
  return (
    await apiFetch<Envelope<EmailTestResult>>(apiPaths.opsEmailTest(), {
      method: "POST",
      body: input,
    })
  ).data;
}

export async function fetchMapKeys(): Promise<MapKeysView> {
  return (await apiFetch<Envelope<MapKeysView>>(apiPaths.opsMapKeys())).data;
}

export async function saveMapKeys(
  body: Partial<Record<MapKeyField, string | null>> & { reason: string },
): Promise<MapKeysView> {
  return (
    await apiFetch<Envelope<MapKeysView>>(apiPaths.opsMapKeys(), { method: "PUT", body })
  ).data;
}

export async function testMapKeys(reason: string): Promise<{ results: MapKeyTestResult[]; view: MapKeysView }> {
  return (
    await apiFetch<Envelope<{ results: MapKeyTestResult[]; view: MapKeysView }>>(
      apiPaths.opsMapKeysTest(),
      { method: "POST", body: { reason } },
    )
  ).data;
}
