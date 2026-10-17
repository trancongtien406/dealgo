export const OPS_DEFAULT_PAGE = 1;
export const OPS_DEFAULT_LIMIT = 20;
export const OPS_MAX_LIMIT = 50;

export type PageResult<T> = {
  items: T[];
  page: number;
  limit: number;
  total: number;
};

export function normalizePage(page: number | undefined): number {
  if (!Number.isSafeInteger(page) || page === undefined || page < 1) {
    return OPS_DEFAULT_PAGE;
  }
  return page;
}

export function normalizeLimit(limit: number | undefined, maxLimit = OPS_MAX_LIMIT): number {
  if (!Number.isSafeInteger(limit) || limit === undefined || limit < 1) {
    return OPS_DEFAULT_LIMIT;
  }
  return Math.min(limit, maxLimit);
}

export function pageOffset(page: number, limit: number): number {
  return (page - 1) * limit;
}

export interface PaginationParams {
  page?: number;
  limit?: number;
}

export interface PaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export function paginate<T>(items: T[], total: number, page = 1, limit = 20): PaginatedResult<T> {
  const safePage = Math.max(1, page);
  const safeLimit = Math.max(1, limit);
  return {
    items,
    total,
    page: safePage,
    limit: safeLimit,
    totalPages: Math.ceil(total / safeLimit),
  };
}
