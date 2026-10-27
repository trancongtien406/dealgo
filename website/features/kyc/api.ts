import {
  kycFilterToNestPartnerStatus,
  mapNestPartnerApplicationToKycCase,
  nestPartnerStatusToFeature,
} from "@/features/kyc/mappers";
import type {
  NestPartnerApplicationList,
  NestPartnerApplicationView,
} from "@/features/kyc/nest-types";
import type { KycCase, KycStatus } from "@/features/kyc/types";
import { apiFetch } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import { apiPaths } from "@/lib/api/paths";

export type FetchKycParams = ListQuery & {
  status?: KycStatus | "ALL";
  /** Partner type; the driver KYC queue must not list merchant (KYB) cases. */
  role?: "DRIVER" | "MERCHANT";
};

/** Nest query for the ops partner-application list. */
export function buildKycQueueSearch(params: FetchKycParams): URLSearchParams {
  const nestStatus = kycFilterToNestPartnerStatus(params.status ?? "ALL");
  const search = new URLSearchParams();
  if (nestStatus) {
    search.set("status", nestStatus);
  } else if (!params.status || params.status === "ALL") {
    search.set("status", "SUBMITTED");
  }
  if (params.role) {
    search.set("role", params.role);
  }
  if (params.page) {
    search.set("page", String(params.page));
  }
  if (params.limit) {
    search.set("limit", String(params.limit));
  }
  if (params.q?.trim()) {
    search.set("q", params.q.trim());
  }
  return search;
}

export async function fetchKycQueue(
  params: FetchKycParams,
): Promise<PaginatedList<KycCase>> {
  return fetchKycFromBff(params);
}

export async function fetchKycByCode(code: string): Promise<KycCase | null> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: NestPartnerApplicationView;
    }>(apiPaths.opsPartnerApplication(code));
    return mapNestPartnerApplicationToKycCase(envelope.data);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) {
      return null;
    }
    throw error;
  }
}

export async function approveKycApplication(
  id: string,
  vehicleClassCode?: string,
): Promise<KycCase> {
  const envelope = await apiFetch<{
    success: boolean;
    data: NestPartnerApplicationView;
  }>(apiPaths.opsPartnerApplicationApprove(id), {
    method: "POST",
    body: vehicleClassCode ? { vehicleClassCode } : {},
  });
  return mapNestPartnerApplicationToKycCase(envelope.data);
}

export async function rejectKycApplication(
  id: string,
  reason: string,
  issues: Array<{ section: string; note: string }> = [],
): Promise<KycCase> {
  const envelope = await apiFetch<{
    success: boolean;
    data: NestPartnerApplicationView;
  }>(apiPaths.opsPartnerApplicationReject(id), {
    method: "POST",
    body: issues.length > 0 ? { reason, issues } : { reason },
  });
  return mapNestPartnerApplicationToKycCase(envelope.data);
}

async function fetchKycFromBff(
  params: FetchKycParams,
): Promise<PaginatedList<KycCase>> {
  if (params.status === "PRIORITY" || params.status === "NEEDS_MORE_INFO") {
    // Nest has no equivalent; empty until product defines mapping.
    return {
      items: [],
      total: 0,
      page: params.page ?? 1,
      limit: params.limit ?? 20,
    };
  }

  const search = buildKycQueueSearch(params);

  const envelope = await apiFetch<{
    success: boolean;
    data: NestPartnerApplicationList;
  }>(`${apiPaths.opsPartnerApplications()}?${search.toString()}`);

  const page = envelope.data.page ?? params.page ?? 1;
  const limit = envelope.data.limit ?? params.limit ?? 20;
  const total = envelope.data.total ?? envelope.data.applications.length;

  const items = envelope.data.applications.map(
    mapNestPartnerApplicationToKycCase,
  );

  return {
    items,
    total,
    page,
    limit,
  };
}

export { nestPartnerStatusToFeature };
