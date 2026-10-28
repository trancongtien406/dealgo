import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function GET() {
  const result = await fetchOpsUpstream({ path: "/v1/ops/payment-methods" });
  return jsonFromOpsUpstream(result);
}

export async function PATCH(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, message: "Dữ liệu không hợp lệ." },
      { status: 400 },
    );
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return NextResponse.json(
      { success: false, message: "Dữ liệu không hợp lệ." },
      { status: 400 },
    );
  }
  const { methods, walletEnabled, reason } = body as Record<string, unknown>;
  if (typeof reason !== "string" || reason.trim().length < 3 || reason.length > 500) {
    return NextResponse.json(
      { success: false, message: "Lý do cần 3–500 ký tự." },
      { status: 400 },
    );
  }
  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: "/v1/ops/payment-methods",
    body: {
      ...(Array.isArray(methods) ? { methods } : {}),
      ...(typeof walletEnabled === "boolean" ? { walletEnabled } : {}),
      reason: reason.trim(),
    },
  });
  return jsonFromOpsUpstream(result);
}
