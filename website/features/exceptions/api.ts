/**
 * Ops exceptions board adapter.
 * Nest GET /v1/ops/exceptions via BFF.
 */
import { mapNestExceptionToCase } from "@/features/exceptions/mappers";
import type { NestExceptionPage } from "@/features/exceptions/nest-types";
import type {
  ExceptionCase,
  ExceptionStatus,
} from "@/features/exceptions/types";
import { apiFetch } from "@/lib/api/client";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import { apiPaths } from "@/lib/api/paths";

export type FetchExceptionsParams = ListQuery & {
  status?: ExceptionStatus | "ALL";
};

export async function fetchExceptions(
  params: FetchExceptionsParams,
): Promise<PaginatedList<ExceptionCase>> {
  return fetchExceptionsFromBff(params);
}

export async function fetchExceptionByCode(
  code: string,
): Promise<ExceptionCase | null> {
  // Nest has list-only; scan first pages for id match.
  for (let page = 1; page <= 5; page += 1) {
    const result = await fetchExceptionsFromBff({
      page,
      limit: 50,
      q: "",
    });
    const found = result.items.find((item) => item.code === code);
    if (found) {
      return found;
    }
    if (result.items.length === 0 || page * 50 >= result.total) {
      break;
    }
  }
  return null;
}

async function fetchExceptionsFromBff(
  params: FetchExceptionsParams,
): Promise<PaginatedList<ExceptionCase>> {
  const search = new URLSearchParams({
    page: String(Math.max(1, params.page)),
    limit: String(Math.max(1, Math.min(50, params.limit))),
  });
  if (params.q?.trim()) {
    search.set("q", params.q.trim());
  }
  if (params.status && params.status !== "ALL") {
    search.set("status", params.status);
  }

  const envelope = await apiFetch<{
    success: boolean;
    data: NestExceptionPage;
  }>(`${apiPaths.opsExceptions()}?${search.toString()}`);

  const items = envelope.data.items.map(mapNestExceptionToCase);

  return {
    items,
    page: envelope.data.page,
    limit: envelope.data.limit,
    total: envelope.data.total,
  };
}
