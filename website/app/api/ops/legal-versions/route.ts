import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function GET() {
  return jsonFromOpsUpstream(await fetchOpsUpstream({ path: "/v1/ops/legal-versions" }));
}

export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) return csrf;
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ success: false, message: "Dữ liệu không hợp lệ." }, { status: 400 });
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return NextResponse.json({ success: false, message: "Dữ liệu không hợp lệ." }, { status: 400 });
  }
  return jsonFromOpsUpstream(await fetchOpsUpstream({ method: "POST", path: "/v1/ops/legal-versions", body }));
}
