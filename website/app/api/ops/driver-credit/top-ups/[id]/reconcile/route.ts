import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

/** Re-query one pending bank transfer at the PSP (idempotent). */
export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã lệnh nạp không hợp lệ." },
      { status: 400 },
    );
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/driver-credit/top-ups/${id}/reconcile`,
  });
  return jsonFromOpsUpstream(result);
}
