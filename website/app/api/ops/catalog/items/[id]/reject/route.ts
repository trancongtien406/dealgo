import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { id } = await context.params;
  if (!id?.trim()) {
    return NextResponse.json(
      { success: false, message: "Mã sản phẩm không hợp lệ." },
      { status: 400 },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/catalog/items/${encodeURIComponent(id)}/reject`,
  });
  return jsonFromOpsUpstream(result);
}
