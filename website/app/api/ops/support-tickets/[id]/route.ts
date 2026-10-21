import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

function invalidId() {
  return NextResponse.json(
    { success: false, message: "Mã yêu cầu hỗ trợ không hợp lệ." },
    { status: 400 },
  );
}

export async function GET(_request: Request, context: RouteContext) {
  const { id } = await context.params;
  if (!id || !isUuid(id)) {
    return invalidId();
  }
  const result = await fetchOpsUpstream({
    path: `/v1/ops/support-tickets/${encodeURIComponent(id)}`,
  });
  return jsonFromOpsUpstream(result);
}

export async function PATCH(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!id || !isUuid(id)) {
    return invalidId();
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
  const { status, priority, reason } = body;
  if (typeof reason !== "string" || reason.trim().length < 3) {
    return NextResponse.json(
      { success: false, message: "Cần ghi lý do (tối thiểu 3 ký tự) để lưu nhật ký kiểm toán." },
      { status: 400 },
    );
  }
  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/support-tickets/${encodeURIComponent(id)}`,
    body: {
      ...(typeof status === "string" ? { status } : {}),
      ...(typeof priority === "string" ? { priority } : {}),
      reason: reason.trim(),
    },
  });
  return jsonFromOpsUpstream(result);
}
