import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ code: string }> };

export async function GET(_request: Request, context: RouteContext) {
  const { code } = await context.params;
  if (!code?.trim()) {
    return NextResponse.json(
      { success: false, message: "Mã chiến dịch không hợp lệ." },
      { status: 400 },
    );
  }

  const result = await fetchOpsUpstream({
    path: `/v1/ops/notifications/${encodeURIComponent(code)}`,
  });
  return jsonFromOpsUpstream(result);
}

export async function PATCH(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { code } = await context.params;
  if (!code?.trim()) {
    return NextResponse.json(
      { success: false, message: "Mã chiến dịch không hợp lệ." },
      { status: 400 },
    );
  }

  let body: unknown = {};
  try {
    body = await request.json();
  } catch {
    body = {};
  }

  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/notifications/${encodeURIComponent(code)}`,
    body,
  });
  return jsonFromOpsUpstream(result);
}
