import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

function bad(message: string) {
  return NextResponse.json({ success: false, message }, { status: 400 });
}

/** Partial or full refund; repeatable until the captured amount (server enforces the cap). */
export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!isUuid(id)) {
    return bad("Mã giao dịch không hợp lệ.");
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return bad("Dữ liệu không hợp lệ.");
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return bad("Dữ liệu không hợp lệ.");
  }
  const { amountVnd, reason } = body as Record<string, unknown>;
  if (typeof amountVnd !== "number" || !Number.isSafeInteger(amountVnd) || amountVnd <= 0) {
    return bad("Số tiền hoàn phải là số nguyên dương.");
  }
  if (typeof reason !== "string" || reason.trim().length < 3 || reason.trim().length > 200) {
    return bad("Lý do cần 3–200 ký tự.");
  }
  const idempotencyKey = request.headers.get("idempotency-key")?.trim() ?? "";
  if (idempotencyKey && !/^[A-Za-z0-9_-]{8,64}$/.test(idempotencyKey)) {
    return bad("Idempotency-Key không hợp lệ.");
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/payment-intents/${id}/refund`,
    body: { amountVnd, reason: reason.trim(), ...(idempotencyKey ? { idempotencyKey } : {}) },
  });
  return jsonFromOpsUpstream(result);
}
