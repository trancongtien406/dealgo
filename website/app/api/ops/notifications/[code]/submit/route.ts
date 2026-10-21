import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ code: string }> };

const MAX_REASON_CHARS = 500;

/** DRAFT → PENDING_APPROVAL (Nest OptionalReasonDto: reason optional, 3–500 when present). */
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
  let json: unknown = {};
  try {
    const text = await request.text();
    json = text.trim() ? JSON.parse(text) : {};
  } catch {
    return NextResponse.json({ success: false, message: "Yêu cầu không hợp lệ." }, { status: 400 });
  }
  const raw =
    typeof json === "object" && json !== null && typeof (json as { reason?: unknown }).reason === "string"
      ? (json as { reason: string }).reason.trim()
      : "";
  if (raw && (raw.length < 3 || raw.length > MAX_REASON_CHARS)) {
    return NextResponse.json(
      { success: false, message: "Ghi chú cần 3–500 ký tự." },
      { status: 400 },
    );
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/notifications/${encodeURIComponent(code)}/submit`,
    body: raw ? { reason: raw } : {},
  });
  return jsonFromOpsUpstream(result);
}
