import { mapNestDriverToListItem } from "@/features/drivers/mappers";
import type {
  NestOpsDriver,
  NestOpsDriverPage,
} from "@/features/drivers/nest-types";
import type { DriverListItem } from "@/features/drivers/types";
import { apiFetch } from "@/lib/api/client";
import type { PaginatedList } from "@/lib/api/pagination";
import { apiPaths } from "@/lib/api/paths";

export type FetchDriversParams = {
  page?: number;
  limit?: number;
  q?: string;
  status?: string | null;
  service?: string | null;
  region?: string | null;
  activity?: string | null;
  kyc?: string | null;
};

export async function fetchDrivers(
  params: FetchDriversParams,
): Promise<PaginatedList<DriverListItem>> {
  return fetchDriversFromBff(params);
}

export async function fetchDriverByCode(
  code: string,
): Promise<DriverListItem | null> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: NestOpsDriver;
    }>(apiPaths.opsDriver(code));
    return mapNestDriverToListItem(envelope.data);
  } catch (error) {
    if (isNotFound(error)) {
      return null;
    }
    throw error;
  }
}

async function fetchDriversFromBff(
  params: FetchDriversParams,
): Promise<PaginatedList<DriverListItem>> {
  const page = Math.max(1, params.page ?? 1);
  const limit = Math.max(1, Math.min(50, params.limit ?? 20));
  const search = new URLSearchParams({
    page: String(page),
    limit: String(limit),
  });
  if (params.q?.trim()) {
    search.set("q", params.q.trim());
  }
  if (params.status && params.status !== "ALL") {
    search.set("status", params.status);
  }
  if (params.service && params.service !== "ALL") {
    search.set("service", params.service);
  }
  if (params.region && params.region !== "ALL") {
    search.set("region", params.region);
  }
  if (params.activity && params.activity !== "ALL") {
    search.set("activity", params.activity);
  }
  if (params.kyc && params.kyc !== "ALL") {
    search.set("kyc", params.kyc);
  }
  const envelope = await apiFetch<{
    success: boolean;
    data: NestOpsDriverPage;
  }>(`${apiPaths.opsDrivers()}?${search.toString()}`);
  const pageData = envelope.data;

  return {
    page: pageData.page,
    limit: pageData.limit,
    total: pageData.total,
    items: pageData.items.map(mapNestDriverToListItem),
  };
}

function isNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code: string }).code === "NOT_FOUND"
  );
}
