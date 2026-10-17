import { NextResponse } from "next/server";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { catalogCategoryLabel } from "@/features/catalog/labels";
import type { CatalogCategory, CatalogStatus } from "@/features/catalog/types";

type RouteContext = { params: Promise<{ code: string }> };

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

export async function GET(_request: Request, context: RouteContext) {
  const { code } = await context.params;
  const result = await fetchOpsUpstream({
    path: `/v1/ops/catalog/categories/${encodeURIComponent(code)}`,
  });
  if (!result.ok) {
    return jsonFromOpsUpstream(result);
  }
  const row = result.data as NestCategory;
  return NextResponse.json({
    success: true,
    data: mapItem(row),
  });
}

export async function PATCH() {
  return NextResponse.json(
    {
      success: false,
      message:
        "Ngành hàng được tổng hợp từ hồ sơ cửa hàng; chỉnh ngành hàng trên cửa hàng.",
    },
    { status: 501 },
  );
}

export async function DELETE() {
  return NextResponse.json(
    {
      success: false,
      message:
        "Không xóa ngành hàng từ Admin; đổi/xóa category trên cửa hàng nguồn.",
    },
    { status: 501 },
  );
}
