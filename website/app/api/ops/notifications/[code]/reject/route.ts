import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ code: string }> };

const MAX_REASON_CHARS = 500;

export async function POST(request: Request, context: RouteContext) {
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

  const body = await readReasonBody(request);
  if (!body.ok) {
    return NextResponse.json(
      { success: false, message: body.message },
      { status: body.status },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/notifications/${encodeURIComponent(code)}/reject`,
    body: { reason: body.reason },
  });
  return jsonFromOpsUpstream(result);
}

async function readReasonBody(
  request: Request,
): Promise<
  { ok: true; reason: string } | { ok: false; status: number; message: string }
> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return { ok: false, status: 415, message: "Yêu cầu không hợp lệ." };
  }
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return { ok: false, status: 400, message: "Yêu cầu không hợp lệ." };
  }
  if (
    typeof json !== "object" ||
    json === null ||
    typeof (json as { reason?: unknown }).reason !== "string"
  ) {
    return { ok: false, status: 400, message: "Nhập lý do từ chối." };
  }
  const reason = (json as { reason: string }).reason.trim();
  if (reason.length < 3 || reason.length > MAX_REASON_CHARS) {
    return { ok: false, status: 400, message: "Nhập lý do từ chối." };
  }
  return { ok: true, reason };
}
