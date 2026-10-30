import { mapNestParcelToListItem } from "@/features/parcels/mappers";
import type { NestParcelPage, NestParcelView, ParcelListItem, ParcelOutcome } from "@/features/parcels/types";
import { apiFetch } from "@/lib/api/client";
import type { PaginatedList } from "@/lib/api/pagination";

export type FetchParcelsParams = { page: number; limit: number; q: string; outcome: ParcelOutcome | "ALL" };

export type OpsParcelDetail = {
  id: string;
  status: string;
  vehicleClassCode?: string;
  pickupLabel?: string | null;
  dropoffLabel?: string | null;
  offeredFareVnd?: number;
  agreedFareVnd?: number | null;
  parcel: NestParcelView;
  [key: string]: unknown;
};

export async function fetchParcels(params: FetchParcelsParams): Promise<PaginatedList<ParcelListItem>> {
  const search = new URLSearchParams({
    page: String(Math.max(1, params.page)),
    limit: String(Math.max(1, Math.min(50, params.limit))),
  });
  if (params.outcome !== "ALL") search.set("outcome", params.outcome);
  if (params.q.trim()) search.set("q", params.q.trim());
  const envelope = await apiFetch<{ success: boolean; data: NestParcelPage }>(`/api/ops/parcels?${search}`);
  const page = envelope.data;
  return { page: page.page, limit: page.limit, total: page.total, items: page.items.map(mapNestParcelToListItem) };
}

export async function fetchParcel(id: string): Promise<OpsParcelDetail> {
  const envelope = await apiFetch<{ success: boolean; data: OpsParcelDetail }>(
    `/api/ops/parcels/${encodeURIComponent(id)}`,
  );
  return envelope.data;
}
