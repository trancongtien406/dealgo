import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function GET() {
  return jsonFromOpsUpstream(await fetchOpsUpstream({ path: "/v1/ops/app-version-policy" }));
}

export async function PATCH(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) return csrf;
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, message: "Dữ liệu không hợp lệ." }, { status: 400 });
  }
  const { policy, reason } = (body && typeof body === "object" ? body : {}) as Record<string, unknown>;
  if (!policy || typeof policy !== "object" || Array.isArray(policy)) {
    return NextResponse.json({ success: false, message: "Dữ liệu không hợp lệ." }, { status: 400 });
  }
  if (typeof reason !== "string" || reason.trim().length < 3 || reason.length > 500) {
    return NextResponse.json({ success: false, message: "Lý do cần 3–500 ký tự." }, { status: 400 });
  }
  return jsonFromOpsUpstream(
    await fetchOpsUpstream({ method: "PATCH", path: "/v1/ops/app-version-policy", body: { policy, reason: reason.trim() } }),
  );
}
