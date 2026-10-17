import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ code: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { code } = await context.params;
  if (!code || code.length > 16) {
    return NextResponse.json(
      { success: false, message: "Mã khu vực không hợp lệ." },
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

  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/zones/${encodeURIComponent(code)}`,
    body,
  });
  return jsonFromOpsUpstream(result);
}
