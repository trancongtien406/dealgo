import { mapNestCustomerToListItem } from "@/features/customers/mappers";
import type {
  NestOpsCustomer,
  NestOpsCustomerPage,
} from "@/features/customers/nest-types";
import type {
  CustomerActivitiesPage,
  CustomerListItem,
  CustomerStatus,
} from "@/features/customers/types";
import { apiFetch } from "@/lib/api/client";
import type { PaginatedList } from "@/lib/api/pagination";
import { apiPaths } from "@/lib/api/paths";

export type FetchCustomersParams = {
  page?: number;
  limit?: number;
  q?: string;
  status?: CustomerStatus | "ALL" | null;
  region?: string | null;
  service?: string | null;
};

export async function fetchCustomers(
  params: FetchCustomersParams,
): Promise<PaginatedList<CustomerListItem>> {
  return fetchCustomersFromBff(params);
}

export async function fetchCustomerByCode(
  code: string,
): Promise<CustomerListItem | null> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: NestOpsCustomer;
    }>(apiPaths.opsCustomer(code));
    return mapNestCustomerToListItem(envelope.data);
  } catch (error) {
    if (isNotFound(error)) {
      return null;
    }
    throw error;
  }
}

export type FetchCustomerActivitiesParams = {
  code: string;
  tab?: string;
  page?: number;
  limit?: number;
};

export async function fetchCustomerActivities(
  params: FetchCustomerActivitiesParams,
): Promise<CustomerActivitiesPage> {
  const page = Math.max(1, params.page ?? 1);
  const limit = Math.max(1, Math.min(50, params.limit ?? 6));
  const search = new URLSearchParams({
    page: String(page),
    limit: String(limit),
  });
  if (params.tab) {
    search.set("tab", params.tab);
  }

  const envelope = await apiFetch<{
    success: boolean;
    data: CustomerActivitiesPage;
  }>(`${apiPaths.opsCustomerActivities(params.code)}?${search.toString()}`);
  return envelope.data;
}

async function fetchCustomersFromBff(
  params: FetchCustomersParams,
): Promise<PaginatedList<CustomerListItem>> {
  const page = Math.max(1, params.page ?? 1);
  const limit = Math.max(1, Math.min(50, params.limit ?? 20));
  const search = new URLSearchParams({
    page: String(page),
    limit: String(limit),
  });
  if (params.status && params.status !== "ALL") {
    search.set("status", params.status);
  }
  if (params.region && params.region !== "ALL") {
    search.set("region", params.region);
  }
  if (params.service && params.service !== "ALL") {
    search.set("service", params.service);
  }
  if (params.q?.trim()) {
    search.set("q", params.q.trim());
  }
  const envelope = await apiFetch<{
    success: boolean;
    data: NestOpsCustomerPage;
  }>(`${apiPaths.opsCustomers()}?${search.toString()}`);
  const pageData = envelope.data;

  return {
    page: pageData.page,
    limit: pageData.limit,
    total: pageData.total,
    items: pageData.items.map(mapNestCustomerToListItem),
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
