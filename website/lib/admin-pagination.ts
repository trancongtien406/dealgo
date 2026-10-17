export const PAGE_SIZE_OPTIONS = [5, 10, 15, 20] as const;

export type PageSize = (typeof PAGE_SIZE_OPTIONS)[number];

export const DEFAULT_PAGE_SIZE: PageSize = 10;

export function isPageSize(value: number): value is PageSize {
  return (PAGE_SIZE_OPTIONS as readonly number[]).includes(value);
}

export function coercePageSize(value: number | null | undefined): PageSize {
  if (value != null && isPageSize(value)) {
    return value;
  }
  return DEFAULT_PAGE_SIZE;
}
