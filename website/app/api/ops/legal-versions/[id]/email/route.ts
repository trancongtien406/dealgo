import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };
const UUID = /^[0-9a-f-]{36}$/i;

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) return csrf;
  const { id } = await context.params;
  if (!UUID.test(id)) return NextResponse.json({ success: false, message: "Không tìm thấy." }, { status: 404 });
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, message: "Dữ liệu không hợp lệ." }, { status: 400 });
  }
  const confirmCount = (body as { confirmCount?: unknown } | null)?.confirmCount;
  if (typeof confirmCount !== "number" || !Number.isInteger(confirmCount) || confirmCount < 0) {
    return NextResponse.json({ success: false, message: "Cần xem trước số người nhận." }, { status: 400 });
  }
  return jsonFromOpsUpstream(
    await fetchOpsUpstream({ method: "POST", path: `/v1/ops/legal-versions/${id}/email`, body: { confirmCount } }),
  );
}
