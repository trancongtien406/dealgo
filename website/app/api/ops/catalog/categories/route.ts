import { NextResponse } from "next/server";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";
import { catalogCategoryLabel } from "@/features/catalog/labels";
import type { CatalogCategory, CatalogStatus } from "@/features/catalog/types";

/** Nest OpsCatalogCategoriesQueryDto max; never forward above this. */
const NEST_CATEGORIES_LIMIT = 50;

type NestCategory = {
  code: string;
  name: string;
  slug: string;
  storeCount: number;
  itemCount: number;
  status: string;
};

function mapStatus(status: string): CatalogStatus {
  return status === "HIDDEN" ? "HIDDEN" : "ACTIVE";
}

function mapItem(row: NestCategory): CatalogCategory {
  return {
    code: row.code,
    name: row.name,
    displayName: catalogCategoryLabel(row.name || row.code),
    slug: row.slug,
    storeCount: row.storeCount,
    itemCount: row.itemCount,
    status: mapStatus(row.status),
  };
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 10, 50);
  const q = searchParams.get("q")?.trim() || undefined;
  const sort = searchParams.get("sort")?.trim() || "STORES";
  const status = searchParams.get("status")?.trim() || undefined;

  const nestLimit = Math.min(NEST_CATEGORIES_LIMIT, 50);

  const result = await fetchOpsUpstream({
    path: "/v1/ops/catalog/categories",
    searchParams: {
      page: 1,
      limit: nestLimit,
      ...(q ? { q } : {}),
    },
  });

  if (!result.ok) {
    return jsonFromOpsUpstream(result);
  }

  const upstream = result.data as {
    items?: NestCategory[];
    total?: number;
  };

  let items = (upstream.items ?? []).map(mapItem);

  if (q) {
    const needle = q.toLowerCase();
    items = items.filter(
      (item) =>
        item.displayName.toLowerCase().includes(needle) ||
        item.code.toLowerCase().includes(needle) ||
        item.slug.toLowerCase().includes(needle),
    );
  }

  if (status === "ACTIVE" || status === "HIDDEN") {
    items = items.filter((item) => item.status === status);
  }

  if (sort === "NAME") {
    items = [...items].sort((a, b) =>
      a.displayName.localeCompare(b.displayName, "vi"),
    );
  } else if (sort === "PRODUCTS") {
    items = [...items].sort((a, b) => b.itemCount - a.itemCount);
  } else {
    items = [...items].sort((a, b) => b.storeCount - a.storeCount);
  }

  const totals = {
    categories: items.length,
    stores: items.reduce((sum, row) => sum + row.storeCount, 0),
    items: items.reduce((sum, row) => sum + row.itemCount, 0),
  };

  const start = (page - 1) * limit;
  const paged = items.slice(start, start + limit);

  return NextResponse.json({
    success: true,
    data: {
      items: paged,
      total: items.length,
      page,
      limit,
      totals,
    },
  });
}
