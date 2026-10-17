export const CATALOG_STATUSES = ["ACTIVE", "HIDDEN"] as const;
export type CatalogStatus = (typeof CATALOG_STATUSES)[number];

/** Nest-derived food store category (aggregated, read-only in Admin). */
export type CatalogCategory = {
  code: string;
  name: string;
  displayName: string;
  slug: string;
  storeCount: number;
  itemCount: number;
  status: CatalogStatus;
};
