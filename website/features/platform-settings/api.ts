import { enrichPlatformSetting } from "@/features/platform-settings/mappers";
import type {
  PlatformSettingRow,
  PlatformSettingsFilterParams,
} from "@/features/platform-settings/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchPlatformSettings(
  params?: PlatformSettingsFilterParams,
): Promise<PlatformSettingRow[]> {
  const sp = new URLSearchParams();
  if (params?.q?.trim()) sp.set("q", params.q.trim());
  // "MONEY" is a client-side view (cash-flow section), not a backend category.
  if (params?.category && params.category !== "ALL" && params.category !== "MONEY")
    sp.set("category", params.category);
  if (params?.source && params.source !== "ALL")
    sp.set("source", params.source);
  const qs = sp.toString() ? `?${sp.toString()}` : "";

  const envelope = await apiFetch<{
    success: boolean;
    data: Array<{
      key: string;
      value: string;
      valueType: PlatformSettingRow["valueType"];
      source: "db" | "env";
      openIds: string[];
      updatedAt: string | null;
      updatedByUserId: string | null;
    }>;
  }>(`${apiPaths.opsPlatformSettings()}${qs}`);
  return envelope.data.map(enrichPlatformSetting);
}

export async function patchPlatformSetting(
  key: string,
  input: { value: string; reason: string },
): Promise<PlatformSettingRow> {
  const envelope = await apiFetch<{
    success: boolean;
    data: {
      key: string;
      value: string;
      valueType: PlatformSettingRow["valueType"];
      source: "db" | "env";
      openIds: string[];
      updatedAt: string | null;
      updatedByUserId: string | null;
    };
  }>(apiPaths.opsPlatformSetting(key), {
    method: "PATCH",
    body: input,
  });
  return enrichPlatformSetting(envelope.data);
}
