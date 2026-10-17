export type ListQuery = {
  page: number;
  limit: number;
  q?: string;
  status?: string | null;
};

export type PaginatedList<T> = {
  page: number;
  limit: number;
  total: number;
  items: T[];
};

export function paginateItems<T>(
  items: readonly T[],
  query: ListQuery,
): PaginatedList<T> {
  const page = Math.max(1, query.page);
  const limit = Math.max(1, Math.min(100, query.limit));
  const start = (page - 1) * limit;
  return {
    page,
    limit,
    total: items.length,
    items: items.slice(start, start + limit),
  };
}

export function matchesQuery(
  haystackParts: readonly string[],
  q: string | null | undefined,
): boolean {
  const needle = q?.trim().toLocaleLowerCase("vi");
  if (!needle) {
    return true;
  }
  return haystackParts.join(" ").toLocaleLowerCase("vi").includes(needle);
}
