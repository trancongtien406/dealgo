/**
 * Ops maps providers (DEC-PROD-045). GET /v1/ops/maps-providers via BFF;
 * changes go through the audited PATCH /v1/ops/platform-settings/:key.
 */
import { mapMapsProviders } from "@/features/maps-providers/mappers";
import type {
  MapsProviderChoice,
  MapsProvidersView,
  NestMapsProviders,
} from "@/features/maps-providers/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchMapsProviders(): Promise<MapsProvidersView> {
  const envelope = await apiFetch<{ success: boolean; data: NestMapsProviders }>(
    apiPaths.opsMapsProviders(),
  );
  return mapMapsProviders(envelope.data);
}

export async function setMapsProvider(
  key: string,
  input: { value: MapsProviderChoice; reason: string },
): Promise<void> {
  await apiFetch<{ success: boolean }>(apiPaths.opsPlatformSetting(key), {
    method: "PATCH",
    body: input,
  });
}
