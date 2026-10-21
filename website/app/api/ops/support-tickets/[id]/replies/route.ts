import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!id || !isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã yêu cầu hỗ trợ không hợp lệ." },
      { status: 400 },
    );
  }
  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return NextResponse.json(
      { success: false, message: "Dữ liệu JSON không hợp lệ." },
      { status: 400 },
    );
  }
  if (typeof body.body !== "string" || body.body.trim().length === 0) {
    return NextResponse.json(
      { success: false, message: "Nội dung phản hồi không được để trống." },
      { status: 400 },
    );
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/support-tickets/${encodeURIComponent(id)}/replies`,
    body: { body: body.body.trim() },
  });
  return jsonFromOpsUpstream(result);
}
