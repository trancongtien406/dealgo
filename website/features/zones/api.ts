import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import { registerServiceRegions } from "@/lib/service-region-labels";
import type {
  CreateZoneInput,
  PatchZoneInput,
  ZoneItem,
  ZoneRule,
} from "@/features/zones/types";

export type FetchZoneRulesParams = ListQuery & {
  service?: string | null;
  status?: string | null;
};

export async function fetchZones(status?: string | null): Promise<ZoneItem[]> {
  const query = status ? `?status=${encodeURIComponent(status)}` : "";
  const res = await apiFetch<{
    success: boolean;
    data: { items: ZoneItem[] };
  }>(`${apiPaths.opsZones()}${query}`);
  const items = res.data.items ?? [];
  registerServiceRegions(items);
  return items;
}

export async function createZone(input: CreateZoneInput): Promise<ZoneItem> {
  const res = await apiFetch<{
    success: boolean;
    data: ZoneItem;
  }>(apiPaths.opsZones(), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  return res.data;
}

export async function patchZone(
  code: string,
  input: PatchZoneInput,
): Promise<ZoneItem> {
  const res = await apiFetch<{
    success: boolean;
    data: ZoneItem;
  }>(`${apiPaths.opsZones()}/${encodeURIComponent(code)}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  return res.data;
}

export type ZonePlaceHit = {
  lat: number;
  lng: number;
  name: string;
  address?: string;
};

/** Backend place search (same providers as the app) for the zone form. */
export async function searchZonePlaces(
  q: string,
  near?: { lat: number; lng: number },
): Promise<ZonePlaceHit[]> {
  const search = new URLSearchParams({ q: q.trim() });
  if (near) {
    search.set("lat", String(near.lat));
    search.set("lng", String(near.lng));
  }
  const res = await apiFetch<{
    success: boolean;
    data: { items?: ZonePlaceHit[]; available?: boolean };
  }>(`${apiPaths.opsPlacesSearch()}?${search.toString()}`);
  return res.data.items ?? [];
}

export async function fetchZoneRules(
  params: FetchZoneRulesParams,
): Promise<PaginatedList<ZoneRule>> {
  const search = new URLSearchParams();
  if (params.page) search.set("page", String(params.page));
  if (params.limit) search.set("limit", String(params.limit));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.service && params.service !== "ALL") {
    search.set("service", params.service);
  }
  if (params.status && params.status !== "ALL") {
    search.set("status", params.status);
  }

  const res = await apiFetch<{
    success: boolean;
    data: PaginatedList<ZoneRule>;
  }>(`${apiPaths.opsZonesRules()}?${search.toString()}`);

  return res.data;
}
